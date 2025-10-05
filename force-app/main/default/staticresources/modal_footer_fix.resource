/* Opt-in: only affects modals while <body> has .mff-active */
.mff-active .slds-modal__container {
  overflow: hidden !important; /* prevents the square plate from peeking out */
}

.mff-active .slds-modal__content {
  border-bottom-left-radius: 1.25rem !important;
  border-bottom-right-radius: 1.25rem !important;
  border-top: 0 !important; /* hides the inner top border line */
  background: var(--lwc-colorBackgroundAlt, #fff) !important; /* keep body white */
}