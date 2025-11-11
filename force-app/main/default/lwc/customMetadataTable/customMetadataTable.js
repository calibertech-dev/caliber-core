import { LightningElement, api, wire, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { getObjectInfo } from 'lightning/uiObjectInfoApi';

import getSObjectApiName from '@salesforce/apex/CustomMetadataTableController.getSObjectApiName';
import deploy from '@salesforce/apex/CustomMetadataTableController.deploy';
import deleteCmdt from '@salesforce/apex/CustomMetadataTableController.deleteCmdt';
import getDeploymentStatus from '@salesforce/apex/CustomMetadataTableController.getDeploymentStatus';

export default class CustomMetadataTable extends LightningElement {
    @api objectApiName;
    @api title = '';
    @api fieldsToDisplay = '';
    @api enableEditing = false;

    @api records = [];

    newRecord = {};
    newRecordDeveloperName = 'test';
    newRecordMasterLabel;

    _draftRecords;
    _deploymentId;

    @track columns = ['DeveloperName'];
    defaultSortDirection = 'asc';
    sortedDirection;
    sortedBy;

    isDeploying = false;
    deploymentStatus;
    deploymentMessage;

    _resolvedDeploymentStatuses = ['Succeeded', 'Failed', 'Aborted'];
    _selectedRows = [];

    // UI helpers
    get disableBulkDelete() {
        return !this._selectedRows || this._selectedRows.length === 0;
    }

    connectedCallback() {
        // When records are provided from Flow, detect the type from the first row
        const first = (this.records && this.records.length > 0) ? this.records[0] : null;
        if (!first) {
            return;
        }
        getSObjectApiName({ customMetadataRecord: first })
            .then(result => {
                this.objectApiName = result;
            })
            .catch(err => {
                this._toast('error', 'Failed to detect object type', this._errMsg(err));
            });
    }

    @wire(getObjectInfo, { objectApiName: '$objectApiName' })
    getSObjectDescribe({ error, data }) {
        if (error) {
            this._toast('error', 'Failed to load object metadata', this._errMsg(error));
            return;
        }
        if (data) {
            this._loadColumns(data.fields);
            if (!this.title) {
                this.title = data.labelPlural;
            }
        }
    }

    // --------- Table events ---------
    handleSelectionChange(event) {
        this._selectedRows = event?.detail?.selectedRows || [];
    }

    handleRowAction(event) {
        const actionName = event.detail.action.name;
        const row = event.detail.row;

        if (actionName === 'delete') {
            this._deleteFullNames([this._fullNameFor(row)]);
        }
    }

    handleSort(/*event*/) {
        // Optional: add client-side sorting if desired.
    }

    handleCancel() {
        const table = this.template.querySelector('lightning-datatable');
        if (table) {
            table.draftValues = [];
        }
    }

    async handleSave() {
        const table = this.template.querySelector('lightning-datatable');
        const draftValues = table ? table.draftValues : [];
        const updatedRecords = this._mergeDraftValues(draftValues);

        if (!updatedRecords || updatedRecords.length === 0) {
            this._toast('info', 'No changes to deploy', null);
            return;
        }

        try {
            await this._deployCustomMetadataRecords(updatedRecords);
            await this._pollDeploymentStatus();
        } catch (e) {
            this._toast('error', 'Deployment failed', this._errMsg(e));
        }
    }

    // --------- Bulk delete ---------
    handleBulkDelete() {
        if (!this._selectedRows || this._selectedRows.length === 0) {
            return;
        }
        const fullNames = this._selectedRows.map(r => this._fullNameFor(r));
        this._deleteFullNames(fullNames);
    }

    // --------- Column building ---------
    _loadColumns(fields) {
        const fieldsMap = new Map(Object.entries(fields));
        const cols = [];

        // Always include row actions
        cols.push({
            type: 'action',
            typeAttributes: {
                rowActions: [
                    { label: 'Delete', name: 'delete', iconName: 'utility:delete', iconPosition: 'left' }
                ],
                menuAlignment: 'right'
            },
            fixedWidth: 80
        });

        // Build columns from provided CSV list (e.g., "DeveloperName, MasterLabel, ExampleTextField__c")
        this.fieldsToDisplay.split(',').forEach(raw => {
            const fieldApiName = (raw || '').trim();
            if (!fieldApiName) {
                return;
            }
            const field = fieldsMap.get(fieldApiName);
            if (field) {
                cols.push(this._generateColumn(field));
            }
        });

        this.columns = cols;
    }

    _generateColumn(field) {
        const col = {
            label: field.label,
            fieldName: field.apiName,
            editable: this.enableEditing && field.apiName !== 'DeveloperName',
            type: (field.dataType || 'string').toLowerCase()
        };

        switch (col.type) {
            case 'date':
                col.type = 'date-local';
                break;
            case 'datetime':
                col.type = 'date';
                col.typeAttributes = {
                    month: '2-digit',
                    day: '2-digit',
                    year: 'numeric',
                    hour: '2-digit',
                    minute: '2-digit'
                };
                break;
            case 'picklist':
                col.typeAttributes = {
                    // Could wire picklist options via Apex if needed
                    value: { fieldName: col.fieldName },
                    context: { fieldName: 'DeveloperName' }
                };
                break;
            case 'string':
                col.type = 'text';
                break;
            case 'reference':
                // Not editable for EntityDefinition/FieldDefinition
                col.editable = false;
                break;
            default:
                // leave type as-is (number, boolean, etc.)
                break;
        }
        return col;
    }

    // --------- Save/Deploy helpers ---------
    _mergeDraftValues(draftValues) {
        if (!draftValues || draftValues.length === 0) {
            return [];
        }

        const mapByDevName = draftValues.reduce((m, d) => {
            if (d && d.DeveloperName) {
                m[d.DeveloperName] = d;
            }
            return m;
        }, {});

        this._draftRecords = [];
        const updatedRecords = [];

        (this.records || []).forEach(rec => {
            const patch = mapByDevName[rec.DeveloperName];
            if (patch) {
                const updated = { ...rec, ...patch };
                this._draftRecords.push(updated);
                updatedRecords.push(updated);
            } else {
                this._draftRecords.push(rec);
            }
        });
        return updatedRecords;
    }

    async _deployCustomMetadataRecords(updatedRecords) {
        try {
            const jobId = await deploy({ customMetadataRecords: updatedRecords });
            this.isDeploying = true;
            this._deploymentId = jobId || null;
        } catch (e) {
            this.isDeploying = false;
            this._deploymentId = null;
            throw e;
        }
    }

    async _pollDeploymentStatus() {
        // In test mode or delete-only flows, jobId can be null
        if (!this._deploymentId) {
            this.isDeploying = false;
            this._toast('success', 'Deployment Completed', 'Saved (test or delete-only path).');
            return;
        }

        // Poll loop
        // Stops when status ∈ _resolvedDeploymentStatuses
        // Wait 2 seconds between checks
        while (true) {
            const resp = await getDeploymentStatus({ deploymentJobId: this._deploymentId });

            if (resp && resp.deployResult) {
                this.deploymentStatus = resp.deployResult.status;

                const failures = (resp.deployResult.details && resp.deployResult.details.componentFailures)
                    ? resp.deployResult.details.componentFailures
                    : null;

                if (failures && failures.length && failures[0] && failures[0].problem) {
                    this.deploymentMessage = 'Error: ' + failures[0].problem;
                } else {
                    this.deploymentMessage = null;
                }
            }

            if (this._resolvedDeploymentStatuses.includes(this.deploymentStatus)) {
                break;
            }
            // sleep 2s
            // eslint-disable-next-line no-await-in-loop
            await new Promise(res => setTimeout(res, 2000));
        }

        this.isDeploying = false;
        if (this.deploymentStatus === 'Succeeded') {
            this.handleCancel();
            // Persist success edits into table
            this.records = this._draftRecords;
            this._toast('success', 'Deployment Completed', 'CMDT records were successfully deployed');
        } else {
            this._toast('error', 'Deployment Finished with Errors', this.deploymentMessage || 'See Error Logs.');
        }
    }

    // --------- Delete helpers ---------
    _fullNameFor(row) {
        // Full name expected by server: <Type__mdt>.<DeveloperName>
        return `${this.objectApiName}.${row.DeveloperName}`;
    }

    async _deleteFullNames(fullNames) {
        if (!fullNames || fullNames.length === 0) {
            return;
        }
        try {
            // Returns null/placeholder in tests; server enqueues queueable in prod
            await deleteCmdt({ customMetadataFullNames: fullNames });
            this._toast('success', 'Delete enqueued', `${fullNames.length} record(s) scheduled for deletion`);

            // Remove deleted rows immediately from UI for responsiveness
            const deletes = new Set(fullNames.map(fn => fn.split('.').pop()));
            this.records = (this.records || []).filter(r => !deletes.has(r.DeveloperName));
            this._selectedRows = [];
        } catch (e) {
            this._toast('error', 'Delete failed', this._errMsg(e));
        }
    }

    // --------- Toast & error helpers ---------
    _toast(variant, title, message) {
        const evt = new ShowToastEvent({
            title: title || '',
            message: message || '',
            variant: variant || 'info'
        });
        this.dispatchEvent(evt);
    }

    _errMsg(e) {
        // Normalize LWC/Apex error formats
        if (!e) return 'Unknown error';
        if (typeof e === 'string') return e;
        if (e.body && e.body.message) return e.body.message;
        if (e.message) return e.message;
        try {
            return JSON.stringify(e);
        } catch {
            return 'Unknown error';
        }
    }
}
