namespace Dino.Plugins.Omemo {

public class Plugin : RootInterface, Object {
    public static Signal.Context context;

    public Dino.Application app;
    public Database db;
    public EncryptionListEntry list_entry;
    public AccountSettingsEntry settings_entry;

    public void registered(Dino.Application app) {
        try {
            context = new Signal.Context(false);
            this.app = app;
            this.db = new Database("omemo.db");
            this.list_entry = new EncryptionListEntry(this);
            this.settings_entry = new AccountSettingsEntry(this);
            this.app.plugin_registry.register_encryption_list_entry(list_entry);
            this.app.plugin_registry.register_account_settings_entry(settings_entry);
            this.app.stream_interaction.module_manager.initialize_account_modules.connect((account, list) => {
                list.add(new StreamModule());
            });
            Manager.start(this.app.stream_interaction, db);
        } catch (Error e) {
            print(@"Error initializing OMEMO: $(e.message)\n");
        }
    }

    public void shutdown() {
        // Nothing to do
    }
}

}