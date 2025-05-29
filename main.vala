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
            application_id: "com.github.SqaurDE.EctoEdit",
            flags: ApplicationFlags.HANDLES_OPEN
        );
    }

    protected override void activate() {
        // Create the main window
        window = new Gtk.ApplicationWindow(this) {
            default_width = 1000,
            default_height = 800,
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

        // Create text view with monospace font
        text_view = new Gtk.TextView() {
            hexpand = true,
            vexpand = true,
            wrap_mode = Gtk.WrapMode.WORD,
            monospace = true
        };
        
        // Set larger font size using CSS on the text buffer
        var css_provider = new Gtk.CssProvider();
        css_provider.load_from_data("textview text { font-size: 14pt; }".data);
        text_view.get_style_context().add_provider(css_provider, Gtk.STYLE_PROVIDER_PRIORITY_USER);
        
        // Set tab width to 4 spaces equivalent
        var tab_array = new Pango.TabArray(1, true);
        tab_array.set_tab(0, Pango.TabAlign.LEFT, 4 * Pango.SCALE);
        text_view.tabs = tab_array;

        // Auto-indentation setup
        text_view.buffer.notify["cursor-position"].connect(() => {
            var buffer = text_view.buffer;
            Gtk.TextIter iter;
            buffer.get_iter_at_mark(out iter, buffer.get_insert());
            
            var line_start = iter.copy();
            line_start.set_line_offset(0);
            
            string line_text = line_start.get_text(iter);
            string whitespace = "";
            
            for (int i = 0; i < line_text.length; i++) {
                if (line_text[i] == ' ' || line_text[i] == '\t') {
                    whitespace += line_text[i].to_string();
                } else {
                    break;
                }
            }
            
            text_view.set_data<string>("indent-pattern", whitespace);
        });

        // Handle key press events
        var controller = new Gtk.EventControllerKey();
        controller.key_pressed.connect((keyval, keycode, state) => {
            if (keyval == Gdk.Key.Return || keyval == Gdk.Key.KP_Enter) {
                var buffer = text_view.buffer;
                string? indent = text_view.get_data<string>("indent-pattern");
                
                if (indent != null) {
                    buffer.insert_at_cursor("\n" + indent, -1);
                    return true;
                }
            }
            return false;
        });
        text_view.add_controller(controller);

        // Create scrolled window for text view
        var scrolled_window = new Gtk.ScrolledWindow() {
            child = text_view
        };

        // Set the window child
        window.child = scrolled_window;
        
        // Connect to close request to handle unsaved changes
        window.close_request.connect(on_close_request);
        
        // Connect to buffer changed signal to enable save button
        text_view.buffer.changed.connect(() => {
            save_button.sensitive = true;
        });
        
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

    private bool on_close_request() {
        if (text_view.buffer.get_modified()) {
            var dialog = new Gtk.AlertDialog("Unsaved Changes");
            dialog.detail = "Do you want to save your changes before closing?";
            dialog.buttons = {"Save", "Don't Save", "Cancel"};
            dialog.default_button = 0;
            dialog.cancel_button = 2;
            
            dialog.choose.begin(window, null, (obj, res) => {
                try {
                    int response = dialog.choose.end(res);
                    switch (response) {
                        case 0: // Save
                            if (current_file != null) {
                                save_to_file(File.new_for_path(current_file));
                                window.destroy();
                            } else {
                                // Need to save as
                                var save_dialog = new Gtk.FileDialog();
                                save_dialog.save.begin(window, null, (obj2, res2) => {
                                    try {
                                        var file = save_dialog.save.end(res2);
                                        current_file = file.get_path();
                                        save_to_file(file);
                                        window.destroy();
                                    } catch (Error e) {
                                        show_error("Could not save file", e.message);
                                    }
                                });
                            }
                            break;
                        case 1: // Don't Save
                            window.destroy();
                            break;
                        case 2: // Cancel
                            // Do nothing, keep window open
                            break;
                    }
                } catch (Error e) {
                    // Handle dialog error, keep window open
                }
            });
            
            return true; // Prevent immediate close
        }
        return false; // Allow close if no changes
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
