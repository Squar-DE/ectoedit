public class TextEditor : Adw.Application {
    private Gtk.Window window;
    private GtkSource.View text_view;
    private GtkSource.Buffer buffer;
    private Gtk.HeaderBar header_bar;
    private Gtk.Button open_button;
    private Gtk.Button save_button;
    private Gtk.Button save_as_button;
    private string? current_file = null;

    public TextEditor() {
        Object(
            application_id: "org.SquarDE.EctoEdit",
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

        // Create source buffer and view
        buffer = new GtkSource.Buffer(null);
        text_view = new GtkSource.View.with_buffer(buffer) {
            hexpand = true,
            vexpand = true,
            wrap_mode = Gtk.WrapMode.WORD,
            monospace = true,
            show_line_numbers = true,
            highlight_current_line = true,
            auto_indent = true,
            indent_width = 4,
            tab_width = 4,
            insert_spaces_instead_of_tabs = true
        };
        
        // Set larger font size using CSS
        var css_provider = new Gtk.CssProvider();
        css_provider.load_from_string("textview text { font-size: 14pt; }");
        text_view.get_style_context().add_provider(css_provider, Gtk.STYLE_PROVIDER_PRIORITY_USER);
        
        // Initialize style scheme
        update_style_scheme();
        
        // Connect to system theme changes
        var settings = Gtk.Settings.get_default();
        settings.notify["gtk-application-prefer-dark-theme"].connect(() => {
            update_style_scheme();
        });

        // Auto-indentation setup (GtkSourceView handles most of this automatically)
        buffer.notify["cursor-position"].connect(() => {
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

        // Handle key press events for additional auto-indentation
        var controller = new Gtk.EventControllerKey();
        controller.key_pressed.connect((keyval, keycode, state) => {
            if (keyval == Gdk.Key.Return || keyval == Gdk.Key.KP_Enter) {
                // GtkSourceView handles most auto-indentation, but we can add custom logic here if needed
                return false; // Let GtkSourceView handle it
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
        buffer.changed.connect(() => {
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
                buffer.text = (string)contents;
                buffer.set_modified(false);
                
                // Set language based on file extension
                set_language_from_filename(files[0].get_basename());
                
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
                buffer.text = (string)contents;
                buffer.set_modified(false);
                
                // Set language based on file extension
                set_language_from_filename(file.get_basename());
                
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
                
                // Set language based on file extension
                set_language_from_filename(file.get_basename());
                
                save_to_file(file);
            } catch (Error e) {
                show_error("Could not save file", e.message);
            }
        });
    }

    private void save_to_file(File file) {
        try {
            var text = buffer.text;
            file.replace_contents(text.data, null, false, FileCreateFlags.NONE, null);
            buffer.set_modified(false);
            window.title = "EctoEdit - " + file.get_basename();
            save_button.sensitive = false;
        } catch (Error e) {
            show_error("Could not save file", e.message);
        }
    }

    private bool on_close_request() {
        if (buffer.get_modified()) {
            // Create a custom dialog with styled buttons
            var dialog = new Adw.AlertDialog("Unsaved Changes", "Do you want to save your changes before closing?");
            
            dialog.add_response("cancel", "Cancel");
            dialog.add_response("discard", "Don't Save");
            dialog.add_response("save", "Save");
            
            dialog.set_response_appearance("discard", Adw.ResponseAppearance.DESTRUCTIVE);
            dialog.set_response_appearance("save", Adw.ResponseAppearance.SUGGESTED);
            
            dialog.set_default_response("save");
            dialog.set_close_response("cancel");
            
            dialog.choose.begin(window, null, (obj, res) => {
                try {
                    string response = dialog.choose.end(res);
                    switch (response) {
                        case "save":
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
                        case "discard":
                            window.destroy();
                            break;
                        case "cancel":
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

    private void update_style_scheme() {
        var style_manager = GtkSource.StyleSchemeManager.get_default();
        var settings = Gtk.Settings.get_default();
        
        string scheme_id;
        if (settings.gtk_application_prefer_dark_theme) {
            // Use dark theme scheme
            scheme_id = "Adwaita-dark";
        } else {
            // Use light theme scheme  
            scheme_id = "Adwaita";
        }
        
        var scheme = style_manager.get_scheme(scheme_id);
        if (scheme != null) {
            buffer.set_style_scheme(scheme);
        }
    }

    private void set_language_from_filename(string filename) {
        var language_manager = GtkSource.LanguageManager.get_default();
        var language = language_manager.guess_language(filename, null);
        buffer.set_language(language);
    }

    private void show_error(string primary, string secondary) {
        var dialog = new Adw.AlertDialog(primary, secondary);
        dialog.add_response("ok", "OK");
        dialog.choose.begin(window, null, null);
    }

    public static int main(string[] args) {
        var app = new TextEditor();
        return app.run(args);
    }
}
