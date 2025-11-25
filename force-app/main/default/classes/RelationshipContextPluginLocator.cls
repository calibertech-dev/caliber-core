public with sharing class RelationshipContextPluginLocator {

    private static IRelationshipContextPlugin cachedPlugin;
    private static Boolean pluginChecked = false;

    /**
     * Returns an implementation of IRelationshipContextPlugin if one exists,
     * otherwise null.
     *
     * Core knows about the interface, but not the concrete implementation.
     * The Multi-Entity package will provide a class named
     * ServiceRelationshipContextPlugin that implements IRelationshipContextPlugin.
     */
    public static IRelationshipContextPlugin getPlugin() {
        if (pluginChecked) {
            return cachedPlugin;
        }

        pluginChecked = true;

        try {
            Type t = Type.forName('ServiceRelationshipContextPlugin');
            if (t != null) {
                Object instance = t.newInstance();
                if (instance instanceof IRelationshipContextPlugin) {
                    cachedPlugin = (IRelationshipContextPlugin)instance;
                }
            }
        } catch (Exception e) {
            cachedPlugin = null;
        }

        return cachedPlugin;
    }
}
