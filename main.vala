using Adw;
using Gtk;

int main (string[] args) {
    var app = new Adw.Application ("com.SquarDE.EctoEdit", ApplicationFlags.DEFAULT_FLAGS);

    app.activate.connect (() => {
        var win = new Adw.ApplicationWindow (app);
        win.set_default_size (500, 400);

        // Layout container
        var box = new Gtk.Box (Orientation.VERTICAL, 0);
        win.set_content (box);

        // HeaderBar inside layout
        var header = new Adw.HeaderBar ();
        header.set_title_widget (new Gtk.Label ("EctoEdit"));

        box.append (header);

        // Add a dummy content widget
        var label = new Gtk.Label ("Welcome to EctoEdit!");
        label.set_valign (Gtk.Align.CENTER);
        label.set_halign (Gtk.Align.CENTER);
        box.append (label);

        win.present ();
    });

    return app.run (args);
}

