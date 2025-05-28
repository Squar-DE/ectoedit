// main.vala
public class TextEditor : Adw.Application {
    private Gtk.Window window;
    private Gtk.TextView text_view;
    private Gtk.HeaderBar header_bar;
    private Gtk.Button open_button;
    private Gtk.Button save_button;
    private Gtk.Button save_as_button;
    private string? current_file = null;

    public TextEditor() {
        Object(
            application_id: "com.github.SquarDE.EctoEdit",
            flags: ApplicationFlags.HANDLES_OPEN
        );
    }

    protected override void activate() {
        // Create the main window
        window = new Gtk.ApplicationWindow(this) {
            default_width = 800,
            default_height = 600,
            title = "EctoEdit"
        };

        // Create header bar
        header_bar = new Gtk.HeaderBar();
        window.set_titlebar(header_bar);

        // Create buttons for header bar
        open_button = new Gtk.Button.from_icon_name("document-open") {
            tooltip_text = "Open File"
        };
        open_button.clicked.connect(on_open_clicked);

        save_button = new Gtk.Button.from_icon_name("document-save") {
            tooltip_text = "Save File",
            sensitive = false
        };
        save_button.clicked.connect(on_save_clicked);

        save_as_button = new Gtk.Button.from_icon_name("document-save-as") {
            tooltip_text = "Save As"
        };
        save_as_button.clicked.connect(on_save_as_clicked);

        header_bar.pack_start(open_button);
        header_bar.pack_end(save_as_button);
        header_bar.pack_end(save_button);

        // Create text view
        text_view = new Gtk.TextView() {
            hexpand = true,
            vexpand = true,
            wrap_mode = Gtk.WrapMode.WORD
        };

        // Buffer signal for modified changes
        text_view.buffer.changed.connect(() => {
            var modified = text_view.buffer.get_modified();
            save_button.sensitive = modified && (current_file != null);
        });

        // Create scrolled window for text view
        var scrolled_window = new Gtk.ScrolledWindow() {
            child = text_view
        };

        // Set the window child
        window.child = scrolled_window;
        window.present();
    }

    protected override void open(File[] files, string hint) {
        if (files.length > 0) {
            try {
                current_file = files[0].get_path();
                uint8[] contents;
                files[0].load_contents(null, out contents, null);
                text_view.buffer.text = (string)contents;
                text_view.buffer.set_modified(false);
                window.title = "EctoEdit - " + files[0].get_basename();
                save_button.sensitive = false;
            } catch (Error e) {
                show_error("Could not open file", e.message);
            }
        }
    }

    private void on_open_clicked() {
        var dialog = new Gtk.FileDialog();
        dialog.open.begin(window, null, (obj, res) => {
            try {
                var file = dialog.open.end(res);
                current_file = file.get_path();
                uint8[] contents;
                file.load_contents(null, out contents, null);
                text_view.buffer.text = (string)contents;
                text_view.buffer.set_modified(false);
                window.title = "EctoEdit - " + file.get_basename();
                save_button.sensitive = false;
            } catch (Error e) {
                show_error("Could not open file", e.message);
            }
        });
    }

    private void on_save_clicked() {
        if (current_file != null) {
            save_to_file(File.new_for_path(current_file));
        }
    }

    private void on_save_as_clicked() {
        var dialog = new Gtk.FileDialog();
        dialog.save.begin(window, null, (obj, res) => {
            try {
                var file = dialog.save.end(res);
                current_file = file.get_path();
                save_to_file(file);
            } catch (Error e) {
                show_error("Could not save file", e.message);
            }
        });
    }

    private void save_to_file(File file) {
        try {
            var text = text_view.buffer.text;
            file.replace_contents(text.data, null, false, FileCreateFlags.NONE, null);
            text_view.buffer.set_modified(false);
            window.title = "EctoEdit - " + file.get_basename();
            save_button.sensitive = false;
        } catch (Error e) {
            show_error("Could not save file", e.message);
        }
    }

    private void show_error(string primary, string secondary) {
        var dialog = new Gtk.AlertDialog(primary);
        dialog.detail = secondary;
        dialog.show(window);
    }

    public static int main(string[] args) {
        var app = new TextEditor();
        return app.run(args);
    }
}
