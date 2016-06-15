#!/usr/bin/env perl

# Binding to the Gio API
BEGIN {
use Glib::Object::Introspection;
	Glib::Object::Introspection->setup(
	basename => 'Gio',
	version => '2.0',
	package => 'Glib::IO');
}

# VARIABLES
# the window
my $window;
# the filenames
my @filenames;
# the labels for the tabs
my @label;
# the changed-status of the tabs
my @changed_status;
# the close buttons on the tabs
my @buttons;
# Eine Liste mit den ganzen Buffer, auf die die Speicher, Öffnen usw. Funktionen zugreifen können
my @buffer;
# Eine Liste mit allen Textviews
my @textview;
# Das Notebook
my $notebook;
# Und eine Variable zum Ermitteln der aktuellen Seite im Notebook
my $n;
# Zum neuen Anlegen bzw. Öffnen einer Datei benötigen wir auch die Anzahl der Seiten (= Nummer der neu angelegten bzw. geöffneten Seite!)
my $m;

# Variables for the SEARCH/REPLACE FUNCTION
# Variables to save a Gtk3::TextIter for the start and end position
# of the current search result
my $startmark;
my $endmark;
# For the search and replace function we need first a search context
# associated with the current buffer
my @search_context;

# Variables for the SYNTAX HIGHLIGHTING FUNCTION
# Create a Language Manager
my $lm = Gtk3::SourceView::LanguageManager->new();
my @languages = $lm->get_language_ids();
# for the syntax highlighting menu a reference to the selected menuitem
my $selected_item;
# and a hash to the menuitems
my %menuitems_syntax;

# The CLASS MyWindow
package MyWindow;

use strict;
use utf8;

use Gtk3;
use Glib ("TRUE","FALSE");
use Gtk3::SourceView;

# Inherit the methods, properties etc. of Gtk3::ApplicationWindow
use base 'Gtk3::ApplicationWindow';


# THE CONSTRUCTOR FUNCTION
sub new {
	my ($window, $app) = @_;
	
	# construct the window
	$window = bless Gtk3::ApplicationWindow->new($app);
	$window->set_title ("PLedit");
	$window->set_default_size (800, 400);
	$window->set_icon_name("accessories-text-editor");
	
	# THE TOOLBAR
	# we create the toolbar in the method create_toolbar (see below)
	#my $toolbar = create_toolbar();
	# the toolbar shall expand horizontally
	#$toolbar->set_hexpand(TRUE);
	# show the toolbar
	#$toolbar->show();

	# Window Actions
	# NEW
	my $new_action = Glib::IO::SimpleAction->new('new', undef);
	$new_action->signal_connect('activate'=>\&new_callback);
	$window->add_action($new_action);
	
	# OPEN
	my $open_action = Glib::IO::SimpleAction->new('open', undef);
	$open_action->signal_connect('activate'=>\&open_callback);
	$window->add_action($open_action);
	
	# SAVE
	my $save_action = Glib::IO::SimpleAction->new('save', undef);
	$save_action->signal_connect('activate'=>\&save_callback);
	$window->add_action($save_action);
	
	# SAVE_AS
	my $save_as_action = Glib::IO::SimpleAction->new('save_as', undef);
	$save_as_action->signal_connect('activate'=>\&save_as_callback);
	$window->add_action($save_as_action);
	
	# RÜCKGÄNGIG
	my $undo_action = Glib::IO::SimpleAction->new('undo', undef);
	$undo_action->signal_connect('activate'=>sub {$buffer[$n]->undo() if ($buffer[$n]->can_undo);});
	$window->add_action($undo_action);
	
	# WIEDERHERSTELLEN
	my $redo_action = Glib::IO::SimpleAction->new('redo', undef);
	$redo_action->signal_connect('activate'=>sub {$buffer[$n]->redo() if ($buffer[$n]->can_redo);});
	$window->add_action($redo_action);
	
	# SUCHEN UND ERSETZEN
	my $search_action = Glib::IO::SimpleAction->new('search', undef);
	$search_action->signal_connect('activate'=>\&search_dialog);
	$window->add_action($search_action);
	
	# SYNTAX CHOICE
	my $toggle_syntax_action = Glib::IO::SimpleAction->new_stateful('toggle_syntax', Glib::VariantType->new('s'), Glib::Variant->new_string('None'));
	$toggle_syntax_action->signal_connect('activate'=>\&toggle_syntax_cb);
	$window->add_action($toggle_syntax_action);

	# A GTK Notebook for the tabs
	$notebook = Gtk3::Notebook->new();
	$notebook->signal_connect("switch-page" => \&change_current_page, $toggle_syntax_action);

	# add the menubar, toolbar and the notebook to a grid
	my $grid=Gtk3::Grid->new();
	#$grid->attach($toolbar,0,1,1,1);
	$grid->attach($notebook,0,2,1,1);

	# add the grid to the window
	$window->add($grid);

	# return the ApplicationWindow
	return $window;
}	


# Function if one syntax highlight module in the Menuitem 
# "Einstellungen->Syntax Hervorhebung" is toggled
sub toggle_syntax_cb {
	my ($action, $parameter) = @_;

	my $string = $parameter->get_string();
	my $lang = $lm->get_language("$string");
	$buffer[$n]->set_language($lang);

	# Note that we set the state of the action
	$action->set_state($parameter);
}

# THE FUNCTION TO CREATE THE TOOLBAR
# AT THE MOMENT DISABLED
sub create_toolbar {
	my $toolbar = Gtk3::Toolbar->new();
	
	# button "new"
	my $new_icon = Gtk3::Image->new_from_icon_name('document-new', '3');
	my $new_button = Gtk3::ToolButton->new($new_icon, 'Neu');
	# label is shown
	$new_button->set_is_important(TRUE);
	# insert the toolbar at position 0 in the toolbar
	$toolbar->insert($new_button, 0);
	# show
	$new_button->show();
	# connect with cb function
	$new_button->signal_connect('clicked'=>\&new_callback);
	
	# button "open"
	my $open_icon = Gtk3::Image->new_from_icon_name('document-open', '3');
	my $open_button = Gtk3::ToolButton->new($open_icon, 'Öffnen');
	# label is shown
	$open_button->set_is_important(TRUE);
	# insert the toolbar at position 0 in the toolbar
	$toolbar->insert($open_button, 1);
	# show
	$open_button->show();
	# connect with cb function
	$open_button->signal_connect('clicked'=>\&open_callback);
	
	# button "save"
	my $save_icon = Gtk3::Image->new_from_icon_name('document-save', '3');
	my $save_button = Gtk3::ToolButton->new($save_icon, 'Speichern');
	# label is shown
	$save_button->set_is_important(TRUE);
	# insert the toolbar at position 0 in the toolbar
	$toolbar->insert($save_button, 2);
	# show
	$save_button->show();
	# connect with cb function
	$save_button->signal_connect('clicked'=>\&save_callback);

	return $toolbar;
}


# THE CALLBACK FUNCTIONS FOR THE MENU ITEMS

# callback for NEW
sub new_callback {
	# Erhalte die Nummer der Seite (=Anzahl aller Seiten)
	$m = $notebook->get_n_pages();
	
	# a scrolled window for the textview
	my $scrolled_window = Gtk3::ScrolledWindow->new();
	$scrolled_window->set_policy("automatic", "automatic");
	$scrolled_window->set_border_width(5);
	# use the set_hexpand and set_vexpand from Gtk3::Widget on the
	# ScrolledWindow to expand it!
	$scrolled_window->set_hexpand(TRUE);
	$scrolled_window->set_vexpand(TRUE);

	# Füge die Seite dem Notebook-Element hinzu
	# Label mit einem x
	my $label_box = Gtk3::Box->new("horizontal", 3);
	if ($filenames[$m]) {
		# Für den im Tab anzuzeigenden Namen benötigen wir die Position
		# des letzten /
		my $pos = rindex($filenames[$m],'/');
		# Schneide nun den Rest als Namen heraus
		my $name = substr($filenames[$m],$pos);
		$label[$m] = Gtk3::Label->new("$name");
	}
	else {
		$label[$m] = Gtk3::Label->new("Untitled");
	}
	$buttons[$m] = Gtk3::Button->new_from_icon_name('window-close', '1');
	$buttons[$m] ->signal_connect('clicked' => \&close_tab, $m);	
	$label_box->pack_start($label[$m], FALSE, FALSE, 3);
	$label_box->pack_start($buttons[$m], FALSE, FALSE, 0);
	$label_box->show_all;

	# Syntax Hervorhebung im Buffer aktivierten
	my $lang = $lm->get_language("perl");
	$buffer[$m] = Gtk3::SourceView::Buffer->new_with_language($lang);	
	$buffer[$m]->set_highlight_syntax(TRUE);
	$buffer[$m]->signal_connect('changed'=>\&changed_text);
	
	$notebook->append_page($scrolled_window,$label_box);
	
	# a textview
	$textview[$m] = Gtk3::SourceView::View->new();
	# displays the buffer
	$textview[$m]->set_buffer($buffer[$m]);
	$textview[$m]->set_highlight_current_line(TRUE);
	$textview[$m]->set_show_line_numbers(TRUE);
	$textview[$m]->set_wrap_mode("word");
	$textview[$m]->set_auto_indent(TRUE);
	$textview[$m]->set_indent_on_tab(TRUE);
	my @flags=("tab");
	$textview[$m]->set_draw_spaces(\@flags);
	
	# For the search and replace function we need first a search context
	# associated with the current buffer
	$search_context[$m] = Gtk3::SourceView::SearchContext->new($buffer[$m]);
	
	$scrolled_window->add($textview[$m]);
	$scrolled_window->show_all();
	
	# go to the new added page
	$notebook->set_current_page("$m");
	
	}

# callbacks for OPEN
sub open_callback {
	# create a filechooserdialog to open:
	# the arguments are: title of the window, parent_window, action
	# (buttons, response)
	my $open_dialog = Gtk3::FileChooserDialog->new("Pick a file", 
						$window,
						"open",
						("gtk-cancel", "cancel", 
						"gtk-open", "accept"));

	# not only local files can be selected in the file selector
	$open_dialog->set_local_only(FALSE);

	# dialog always on top of the textview window
	$open_dialog->set_modal(TRUE);

	# connect the dialog with the callback function open_response_cb()
	$open_dialog->signal_connect("response" => \&open_response_cb);

	# show the dialog
	$open_dialog->show();

	}
	
# callback function for the resonse of the open_dialog
sub open_response_cb {

	my ($dialog, $response_id) = @_;
	my $open_dialog = $dialog;


	# if response id is "ACCEPTED" (the button "Open" has been clicked)
	if ($response_id eq "accept") {
	
		new_callback();
		#$n = $m;

		# $filenames[$n] is the file that we get from the FileChooserDialog
		$filenames[$n] = $open_dialog->get_filename();

		open my $fh, "<:encoding(utf-8)", $filenames[$n];
		my $content="";
		while (my $line=<$fh>) {
			$content = $content . $line;
		}
		# important: we need the length in byte!! Usually the perl function
		# length deals in logical characters, not in physical bytes! For how
		# many bytes a string encoded as UTF-8 would take up, we have to use
		# length(Encode::encode_utf8($content) (for that we have to "use Encode"
		# first [see more http://perldoc.perl.org/functions/length.html]
		# Alternative solutions: 1) open with tag "<:encoding(utf8)"
		# 2) For insert all the text set length in the $buffer->set_text method 
		# 	to -1 (!text must be nul-terminated)
		# 3) In Perl Gtk3 the length argument is optional! Without length 
		#	all text is inserted
		my $length = length(Encode::encode_utf8($content));
		$buffer[$n]->set_text($content,$length);
		
		# Für den im Tab anzuzeigenden Namen benötigen wir die Position
		# des letzten /
		my $pos = rindex($filenames[$n],'/');
		# Schneide nun den Rest als Namen heraus
		my $name = substr($filenames[$n],$pos);
		$label[$n]->set_label("$name");
		$changed_status[$n]='0';
		$dialog->destroy();
		}
	# if response id is "CANCEL" (the button "Cancel" has been clicked)
	elsif ($response_id eq "cancel") {
		$dialog->destroy();
		}
	}

# callback function for SAVE
sub save_callback {
	# if $filenames[$n] is not already there
	if ($filenames[$n]) {
		# get the content of the buffer, without hidden characters
		my ($start, $end) = $buffer[$n]->get_bounds();
		my $content = $buffer[$n]->get_text($start, $end, FALSE);

		open my $fh, ">:encoding(utf8)", $filenames[$n];
		print $fh "$content";
		close $fh;
		
		# Für den im Tab anzuzeigenden Namen benötigen wir die Position
		# des letzten /
		my $pos = rindex($filenames[$n],'/');
		# Schneide nun den Rest als Namen heraus
		my $name = substr($filenames[$n],$pos);
		$label[$n]->set_label("$name");
		
		$changed_status[$n]="0";
		print "$content in $filenames[$n] gespeichert \n";
	}
	else {
		# use save_as_callback
		save_as_callback();
	}
}

# callback functions for SAVE_AS
sub save_as_callback {
	# create a filechooserdialog to save:
	# the arguments are: title of the window, parent_window, action,
	# (buttons, response)
	my $save_dialog = Gtk3::FileChooserDialog->new("Pick a file", 
							$window, 
							"save", 
							("gtk-cancel", "cancel",
							"gtk-save", "accept"));
	# the dialog will present a confirmation dialog if the user types a file name
	# that already exists
	$save_dialog->set_do_overwrite_confirmation(TRUE);
	# dialog always on top of the textview window
	$save_dialog->set_modal(TRUE);

	if ($filenames[$n]) {
	# With the following code line we make the opened file preselected!
	$save_dialog->select_filename($filenames[$n]);
	}

	# connect the dialog to the callback function save_response_cb
	$save_dialog->signal_connect("response" => \&save_response_cb);

	# show the dialog
	$save_dialog->show();
}

# Callback Function for the response of the save-as and save dialog 
# (= saving the file!)
sub save_response_cb {

	my ($dialog, $response_id) = @_;
	my $save_dialog = $dialog;
	
	# if response id is "ACCEPTED" (the button "Open" has been clicked)
	if ($response_id eq "accept") {
		
		# Erhalte den Filename
		$filenames[$n] = $save_dialog->get_filename();

		# get the bcontent of the buffer, without hidden characters
		my ($start, $end) = $buffer[$n]->get_bounds();
		my $content = $buffer[$n]->get_text($start, $end, FALSE);

		open my $fh, ">:encoding(utf8)", $filenames[$n];
		print $fh "$content";
		close $fh;

		# Für den im Tab anzuzeigenden Namen benötigen wir die Position
		# des letzten /
		my $pos = rindex($filenames[$n],'/');
		# Schneide nun den Rest als Namen heraus
		my $name = substr($filenames[$n],$pos);
		$label[$n]->set_label("$name");
		$changed_status[$n]="";
		print "$content in $filenames[$n] gespeichert \n";

		$dialog->destroy();
		}
	# if response id is "CANCEL" (the button "Cancel" has been clicked)
	elsif ($response_id eq "cancel") {
		$dialog->destroy();
		}
}


# Call back functions for SEARCH/REPLACE
sub search_dialog {
	# create a Dialog
	my $search_dialog = Gtk3::Window->new('toplevel');
	$search_dialog->set_title("Suchen und Ersetzen");
	
	# $window is the parent of the dialog
	$search_dialog->set_transient_for($window);
	
	# set modal FALSE, but destroy with parent
	$search_dialog->set_modal(TRUE);
	#$search_dialog->set_destroy_with_parent(TRUE);
	
	# get content area to add entrys for the search
	my $label_searchstring = Gtk3::Label->new('Suchstring:');
	my $entry_searchstring = Gtk3::Entry->new();
	my $label_replacestring = Gtk3::Label->new('Ersetzen durch:');
	my $entry_replacestring = Gtk3::Entry->new();
	
	# A horizontale Box to add the widgets
	my $content_area = Gtk3::Box->new('vertical', 5);
	$content_area->add($label_searchstring);
	$content_area->add($entry_searchstring);
	$content_area->add($label_replacestring);
	$content_area->add($entry_replacestring);

	# the buttons
	my $button_close = Gtk3::Button->new('Schließen');
	my $button_search = Gtk3::Button->new('Suchen');
	my $button_replace = Gtk3::Button->new('Ersetzen');
	
	# connect the response signal to the function search_cb
	my @arguments = ($search_dialog, $entry_searchstring, $entry_replacestring);
	my $data = \@arguments;
	$button_close->signal_connect('clicked'=>\&search_cb, $data);
	$button_search->signal_connect('clicked'=>\&search_cb, $data);
	$button_replace->signal_connect('clicked'=>\&search_cb, $data);

	
	# a horizontale Box to add the buttons
	my $action_area = Gtk3::Box->new('horizontal', '5');
	$action_area->add($button_close);
	$action_area->add($button_replace);
	$action_area->add($button_search);
		
	# A horizontal Box to add the content
	my $content_box = Gtk3::Box->new('vertical', 5);
	$content_box->add($content_area);
	$content_box->add($action_area);
		
	# show the dialog
	$search_dialog->add($content_box);
	$search_dialog->show_all();
}

# RUN THE SEARCH
sub search_cb {
	my ($button, $data) = @_;
	my $search_dialog = $data->[0];
	my $entry_searchstring = $data->[1];
	my $entry_replacestring = $data->[2];
	my $searchstring = $entry_searchstring->get_text();
	my $replacestring = $entry_replacestring->get_text();
	my $label = $button->get_label();
	
	if ($label eq 'Schließen') {
		$startmark='';
		$endmark='';
		$search_dialog->destroy();
	}
	elsif ($label eq 'Suchen') {
		search($searchstring, $replacestring);
	}
	elsif ($label eq 'Ersetzen') {
		# Replacement is only possible, if there is a current search result
		# This is the case, if $end is defined (see above)
		if ($endmark) {		
			# for replacing we need again the iter at the start- and 
			# endmark
			my $startiter = $buffer[$n]->get_iter_at_mark($startmark);
			my $enditer = $buffer[$n]->get_iter_at_mark($endmark);
			# Replace the current search result
			my $replace=$search_context[$n]->replace($startiter, $enditer, "$replacestring", -1);
			
			# After the replacement it will be usually jumped to the
			# next search result
			search($searchstring, $replacestring);
		}
	}
}

# NOW REALLY RUN THE SEARCH :-)
sub search {
	my ($searchstring, $replacestring) = @_;
		# First we need a Gtk3::SourceView::SearchSettings object
		# This element represents the settings of a search and can be associated
		# with one or several Gtk3::SourceView::SearchContexts
		my $search_settings = Gtk3::SourceView::SearchSettings->new();
		# here we just want to set the text to search as 'searchstring'
		# Usually (if the search text is given by an entry or the like)
		# you may be interested to call Gtk3::SourceView::Utils::unescape_search_text
		# before this function. Here this is not necessary.
		$search_settings->set_search_text("$searchstring");
		# Last we associate the $search_settings with the $search_context
		$search_context[$n]->set_settings($search_settings);
		
		# The single search run
		# We need a Gtk3::TextIter for the first search run,
		# because there $end is not defined
		my $cursor = $buffer[$n]->get_insert();
		my $startiter = $buffer[$n]->get_iter_at_mark($cursor);
		my $enditer;
		# The Gtk3::SourceView::SearchContext::forward
		# function returns an array with one Gtk3::Textiter
		# each start and end position of the search result
		my @treffer;
		# If one search run is already passed, we want to start the 
		# current search run after the previous search result
		if ($endmark) {
			# Note: To avoid warning, we first check, whether there is
			# a further result
			# therefore we have again to reconvert the endmark to an iter
			my $end = $buffer[$n]->get_iter_at_mark($endmark);
			if ($search_context[$n]->forward($end)) {
				# perform the search and save the Gtk3::Iters to @treffer
				@treffer = $search_context[$n]->forward($end);
				# Save the Gtk3::TextIter for the start position of the result
				# in the variable $start
				$startiter = @treffer[0];
				# Save the Gtk3::TextIter for the end position of the result
				# in the variable $end
				$enditer = @treffer[1];
				# Note: The concept of "current match" doesn't exist yet. 
				# A way to highlight differently the current match is to select it.
				$buffer[$n]->select_range($startiter, $enditer);
				# important: We need a mark instead of an iter in the
				# case, that the buffer is changed in the meantime, AND
				# scroll to  the selection bound
				$buffer[$n]->create_mark('startmark',$startiter,TRUE);
				$startmark=$buffer[$n]->get_mark('startmark');
				$buffer[$n]->create_mark('endmark',$enditer,TRUE);
				$endmark=$buffer[$n]->get_mark('endmark');
				# scroll to the selection
				my $x = $textview[$n]->scroll_to_mark($startmark, 0.0,TRUE, 0.0, 0.4);
			}
			# If no further result exists, we start searching from the beginning
			else {
				$end = $buffer[$n]->get_start_iter();
				@treffer = $search_context[$n]->forward($end);
				$startiter = @treffer[0];
				$enditer = @treffer[1];
				$buffer[$n]->select_range($startiter, $enditer);
				# important: We need a mark instead of an iter in the
				# case, that the buffer is changed in the meantime, AND
				# scroll to  the selection bound
				$buffer[$n]->create_mark('startmark',$startiter,TRUE);
				$startmark=$buffer[$n]->get_mark('startmark');
				$buffer[$n]->create_mark('endmark',$enditer,TRUE);
				$endmark=$buffer[$n]->get_mark('endmark');
				# scroll to the selection
				my $x = $textview[$n]->scroll_to_mark($startmark, 0.0,TRUE, 0.0, 0.4);
			}
		}
		# In the first search run $end is not defined
		# Therefore we start the first run at the Gtk3::TextIter
		# $startiter which points to the beginning of the buffer
		else {
			if ($search_context[$n]->forward($startiter)) {
				@treffer = $search_context[$n]->forward($startiter);
				$startiter = @treffer[0];
				$enditer = @treffer[1];
				$buffer[$n]->select_range($startiter, $enditer);
				# important: We need a mark instead of an iter in the
				# case, that the buffer is changed in the meantime, AND
				# scroll to  the selection bound
				$buffer[$n]->create_mark('startmark',$startiter,TRUE);
				$startmark=$buffer[$n]->get_mark('startmark');
				$buffer[$n]->create_mark('endmark',$enditer,TRUE);
				$endmark=$buffer[$n]->get_mark('endmark');
				# scroll to the selection
				my $x = $textview[$n]->scroll_to_mark($startmark, 0.0,TRUE, 0.0, 0.4);
			}
		}
}

# call bach function if TEXT IN A BUFFER CHANGED
sub changed_text {
	if ($filenames[$n]) {
		# Für den im Tab anzuzeigenden Namen benötigen wir die Position
		# des letzten /
		my $pos = rindex($filenames[$n],'/');
		# Schneide nun den Rest als Namen heraus
		my $name = substr($filenames[$n],$pos);
		$label[$n]->set_label("$name *");
	}
	else { 
	$label[$n]->set_label("Untitled *");
	}
	$changed_status[$n]=1;
}	


# callback function for CHANGING THE TAB/PAGE
# Wenn der Benutzer die Seite wechselt, muss auch die Variable $n auf die neue Seite verweisen
sub change_current_page {
	my ($notebook, $page_content, $page, $toggle_syntax_action) = @_;
	$n = $page;
	
	# Ändere die Language Einstellung
	# Ändere die Sprache des aktuellen Buffers
	my $lang = $buffer[$n]->get_language();
	my $lang_id = $lang->get_id();
	my $parameter = Glib::Variant->new_string("$lang_id");
	$toggle_syntax_action->set_state($parameter);
}


# Funktionen, wenn CLOSE BUTTON OF A TAB gedrückt wird
sub close_tab {
	my ($button, $m) = @_;
	if ($changed_status[$m] == '1') {
		# a Gtk3::MessageDialog
		my $messagedialog = Gtk3::MessageDialog->new($window,
							'modal',
							'warning',
							'yes_no',
							"Datei wurde geändert. Aenderungen speichern?");

		# connect the response to the function dialog_response
		$messagedialog->signal_connect('response'=>\&close_tab_save_dialog, $m);
		$messagedialog->show();
		}
	else {
		# splice the elements with index $m from the arrays
		splice @filenames, $m, 1;
		splice @label, $m, 1;
		splice @changed_status, $m, 1;
		splice @buttons, $m, 1;
		splice @buffer, $m, 1;
		splice @textview, $m, 1;
		# and remove the page
		$notebook->remove_page($m);
		# set $n to the current page
		my $page = $notebook->get_current_page();
		$n = $page;
		# Das durch die x-Button jeweils übergebene Argument muss noch geändert werden
		# da sich der Index um 1 verringert hat
		for (my $i = 0; $i<= $#buttons; $i++) {
			$buttons[$i]->signal_connect('clicked'=>\&close_tab, $i);
		}
		
	} 
}

# function, if TEXT IN THE TAB WAS CHANGED AND SHOULD BE SAVED BEFORE CLOSING
sub close_tab_save_dialog {
	my ($widget, $response_id, $m) = @_;
	chomp $response_id ;
	if ($response_id eq 'yes') {
		if ($filenames[$m]) {
			# get the content of the buffer, without hidden characters
			my ($start, $end) = $buffer[$m]->get_bounds();
			my $content = $buffer[$m]->get_text($start, $end, FALSE);
	
			open my $fh, ">:encoding(utf8)", $filenames[$m];
			print $fh "$content";
			close $fh;
			
			print "$content in $filenames[$m] gespeichert \n";
			
			# splice the elements with index $m from the arrays
			splice @filenames, $m, 1;
			splice @label, $m, 1;
			splice @changed_status, $m, 1;
			splice @buttons, $m, 1;
			splice @buffer, $m, 1;
			splice @textview, $m, 1;
			# and remove the page
			$notebook->remove_page($m);
			# set $n to the current page
			my $page = $notebook->get_current_page();
			$n = $page;		
			# Das durch die x-Button jeweils übergebene Argument muss noch geändert werden
			# da sich der Index um 1 verringert hat
			for (my $i = 0; $i<= $#buttons; $i++) {
			$buttons[$i]->signal_connect('clicked'=>\&close_tab, $i);
			}
		}
		else {
			# create a filechooserdialog to save:
			# the arguments are: title of the window, parent_window, action,
			# (buttons, response)
			my $save_dialog = Gtk3::FileChooserDialog->new("Pick a file", 
							$window, 
							"save", 
							("gtk-cancel", "cancel",
							"gtk-save", "accept"));
			# the dialog will present a confirmation dialog if the user types a file name
			# that already exists
			$save_dialog->set_do_overwrite_confirmation(TRUE);
			# dialog always on top of the textview window
			#$save_dialog->set_modal(TRUE);

			# connect the dialog to the callback function save_response_cb
			$save_dialog->signal_connect("response" => \&save_before_close_tab, $m);

			# show the dialog
			$save_dialog->show();
		}
	}
	else {
			# splice the elements with index $m from the arrays
			splice @filenames, $m, 1;
			splice @label, $m, 1;
			splice @changed_status, $m, 1;
			splice @buttons, $m, 1;
			splice @buffer, $m, 1;
			splice @textview, $m, 1;
			# and remove the page
			$notebook->remove_page($m);
			# set $n to the current page
			my $page = $notebook->get_current_page();
			$n = $page;
			# Das durch die x-Button jeweils übergebene Argument muss noch geändert werden
			# da sich der Index um 1 verringert hat
			for (my $i = 0; $i<= $#buttons; $i++) {
			$buttons[$i]->signal_connect('clicked'=>\&close_tab, $i);
			}
	}
	
	# finally destroy the messagedialog
	$widget->destroy();
} 

# SAVING THE TEXT IN A CLOSING TAB
sub save_before_close_tab {
	my ($dialog, $response_id,$m) = @_;
	my $save_dialog = $dialog;
	
	# if response id is "ACCEPTED" (the button "Open" has been clicked)
	if ($response_id eq "accept") {
		
		# Erhalte den Filename
		$filenames[$n] = $save_dialog->get_filename();

		# get the bcontent of the buffer, without hidden characters
		my ($start, $end) = $buffer[$n]->get_bounds();
		my $content = $buffer[$n]->get_text($start, $end, FALSE);

		open my $fh, ">:encoding(utf8)", $filenames[$n];
		print $fh "$content";
		close $fh;
		
		print "$content in $filenames[$n] gespeichert \n";
		
		$dialog->destroy();
		# splice the elements with index $m from the arrays
		splice @filenames, $m, 1;
		splice @label, $m, 1;
		splice @changed_status, $m, 1;
		splice @buttons, $m, 1;
		splice @buffer, $m, 1;
		splice @textview, $m, 1;
		# and remove the page
		$notebook->remove_page($m);
		# set $n to the current page
		my $page = $notebook->get_current_page();
		$n = $page;
		# Das durch die x-Button jeweils übergebene Argument muss noch geändert werden
		# da sich der Index um 1 verringert hat
		for (my $i = 0; $i<= $#buttons; $i++) {
			$buttons[$i]->signal_connect('clicked'=>\&close_tab, $i);
		}
	}
	# if response id is "CANCEL" (the button "Cancel" has been clicked)
	elsif ($response_id eq "cancel") {
		$dialog->destroy();
		}
}

# Functions at the DELETE-EVENT
sub quit_cb {
	# Erhalte die Anzahl der offenen Tabs:
	my $pages = $notebook->get_n_pages();
	if ($pages == 1 && $changed_status[$n] == 1) {
		# a Gtk3::MessageDialog
		my $messagedialog = Gtk3::MessageDialog->new($window,
							'modal',
							'other',
							'yes_no',
							"Datei wurde geändert. Aenderungen speichern?");
		
		# connect the response to the function dialog_response
		$messagedialog->signal_connect('response'=>\&quit_save_dialog, $m);
		$messagedialog->show_all();
	}
	elsif ($pages > 1) {
		# a Gtk3::MessageDialog
		my $messagedialog = Gtk3::MessageDialog->new($window,
							'modal',
							'other',
							'ok_cancel',
							"Es sind mehrere Tabs geöffnet. Nicht gespeicherte Änderungen gehen verloren. PLedit dennoch beenden?");
		
		# connect the response to the function dialog_response
		$messagedialog->signal_connect('response'=>\&quit_save_dialog, $m);
		$messagedialog->show_all();
	}
	else {
		print "Terminating... \n";
		
	}
}

# function, if TEXT IN A SINGLE TAB WAS CHANGED AND SHOULD BE SAVED BEFORE EXIT
sub quit_save_dialog {
	my ($widget, $response_id, $m) = @_;
	if ($response_id eq 'yes') {
		if ($filenames[$m]) {
			# get the content of the buffer, without hidden characters
			my ($start, $end) = $buffer[$m]->get_bounds();
			my $content = $buffer[$m]->get_text($start, $end, FALSE);
	
			open my $fh, ">:encoding(utf8)", $filenames[$m];
			print $fh "$content";
			close $fh;
			
			
		}
		else {
			# create a filechooserdialog to save:
			# the arguments are: title of the window, parent_window, action,
			# (buttons, response)
			my $save_dialog = Gtk3::FileChooserDialog->new("Pick a file", 
							$window, 
							"save", 
							("gtk-cancel", "cancel",
							"gtk-save", "accept"));
			# the dialog will present a confirmation dialog if the user types a file name
			# that already exists
			$save_dialog->set_do_overwrite_confirmation(TRUE);
			# dialog always on top of the textview window
			#$save_dialog->set_modal(TRUE);

			# connect the dialog to the callback function save_response_cb
			$save_dialog->signal_connect("response" => \&save_before_quit, $m);

			# show the dialog
			$save_dialog->show();
		}
	# finally destroy the messagedialog
	$widget->destroy();
	}
	elsif ($response_id eq 'no') {
		
	}
	elsif ($response_id eq 'cancel') {
		$widget->destroy();
	}
	elsif ($response_id eq 'ok') {
		
	}

} 

# SAVING THE TEXT IN A SINGLE TAB BEFOR EXIT
sub save_before_quit {
	my ($dialog, $response_id,$m) = @_;
	my $save_dialog = $dialog;
	
	# if response id is "ACCEPTED" (the button "Open" has been clicked)
	if ($response_id eq "accept") {
		
		# Erhalte den Filename
		$filenames[$n] = $save_dialog->get_filename();

		# get the bcontent of the buffer, without hidden characters
		my ($start, $end) = $buffer[$n]->get_bounds();
		my $content = $buffer[$n]->get_text($start, $end, FALSE);

		open my $fh, ">:encoding(utf8)", $filenames[$n];
		print $fh "$content";
		close $fh;
		
		print "$content in $filenames[$n] gespeichert \n";
	}
	# if response id is "CANCEL" (the button "Cancel" has been clicked)
	elsif ($response_id eq "cancel") {
		$dialog->destroy();
		}
}


# The MAIN Program
package main;

use strict;
use warnings;
use Gtk3;
use Gtk3::SourceView;
use Glib ('TRUE','FALSE');

# flag 'non-unique' is needed so that no single-instance negotiation is done,
# that means the App doesn't attemp to become owner of the Application ID and doesn't
# check if an existing owner already exists
my $app = Gtk3::Application->new('PLedit.id','non-unique');

$app->signal_connect('startup' => \&_init);
$app->signal_connect('activate' => \&_build_ui);
$app->signal_connect('shutdown' => \&_shutdown);

$app->run();

exit;

# The CALLBACK FUNCTIONS to the SIGNALS fired by the main function.
sub _init {
	my ($app) = @_;
	
	# the MENU
	my $syntax_section =
	"<item>
		<attribute name = 'label'>None</attribute>
		<attribute name = 'action'>win.toggle_syntax</attribute>
		<attribute name = 'target'>None</attribute>
	</item>";

	# Nun werden die vorhandenen Sprachdateien hinzugefügt
	# Variables for the SYNTAX HIGHLIGHTING FUNCTION
	# Create a Language Manager
	#my $lm = Gtk3::SourceView::LanguageManager->new();
	#my @languages = $lm->get_language_ids();

	my $i=1;
	foreach my $key (@languages) {
		my $item =
			"<item>
			<attribute name = 'label'>$key</attribute>
			<attribute name = 'action'>win.toggle_syntax</attribute>
			<attribute name = 'target'>$key</attribute>
		</item>";
		$syntax_section = $syntax_section . $item;
	}
	my $menu =
	"<?xml version='1.0'? encoding='UTF8'?>
	<interface>
		<menu id='menubar'>
			<submenu>
				<attribute name='label'>File</attribute>
				<section>
					<item>
						<attribute name='label'>New</attribute>
						<attribute name='action'>win.new</attribute>
						<attribute name='accel'>&lt;Primary&gt;n</attribute>
					</item>
					<item>
						<attribute name='label'>Open</attribute>
						<attribute name='action'>win.open</attribute>
						<attribute name='accel'>&lt;Primary&gt;o</attribute>
					</item>
					<item>
						<attribute name='label'>Save</attribute>
						<attribute name='action'>win.save</attribute>
						<attribute name='accel'>&lt;Primary&gt;s</attribute>
					</item>
					<item>
						<attribute name='label'>Save as</attribute>
						<attribute name='action'>win.save_as</attribute>
					</item>
					<item>
						<attribute name='label'>Quit</attribute>
						<attribute name='action'>app.quit</attribute>
						<attribute name='accel'>&lt;Primary&gt;q</attribute>
					</item>
				</section>
			</submenu>
			<submenu>
				<attribute name='label'>Edit</attribute>
				<section>
					<item>
						<attribute name='label'>Undo</attribute>
						<attribute name='action'>win.undo</attribute>
						<attribute name='accel'>&lt;Primary&gt;z</attribute>
					</item>
					<item>
						<attribute name='label'>Redo</attribute>
						<attribute name='action'>win.redo</attribute>
						<attribute name='accel'>&lt;Primary&gt;y</attribute>
					</item>
					<item>
						<attribute name='label'>Search/Replace</attribute>
						<attribute name='action'>win.search</attribute>
						<attribute name='accel'>&lt;Primary&gt;f</attribute>
					</item>
				</section>
			</submenu>
			<submenu>
				<attribute name='label'>Settings</attribute>
				<section>
					<submenu>
						<attribute name='label'>Syntax-Highlighting</attribute>
						<section>
							$syntax_section
						</section>
					</submenu>
				</section>
			</submenu>
			<submenu>
				<attribute name='label'>Help</attribute>
				<section>
					<item>
						<attribute name='label'>About PLedit</attribute>
						<attribute name='action'>app.about</attribute>
					</item>
				</section>
			</submenu>
		</menu>
	</interface>";
	
	# A builder to add the Menu
	my $builder = Gtk3::Builder->new();
	$builder->add_from_string($menu);
	
	# Add the menubar to the application
	my $menubar = $builder->get_object('menubar');
	
	# the App.Actions
	my $quit_action = Glib::IO::SimpleAction->new('quit',undef);
	$quit_action->signal_connect('activate' => sub {$app->quit();});
	$app->add_action($quit_action);
	
	my $about_action = Glib::IO::SimpleAction->new('about',undef);
	$about_action->signal_connect('activate' => \&about_cb);
	$app->add_action($about_action);
	
	$app->set_menubar($menubar);
}

sub _build_ui {
	my ($app) = @_;
	
	# Building the Gtk3::ApplicationWindow and its content is done by a seperate class
	$window = MyWindow->new($app);
	$window->show_all();
}

sub _shutdown {
	my ($app) = @_;

	$window->quit_cb();
	$app->quit();
}

# call back function for ABOUT
# ABOUT DIALOG
sub about_cb {
	# a Gtk3::AboutDialog
	my $aboutdialog = Gtk3::AboutDialog->new();
	$aboutdialog->set_transient_for($window);
	$aboutdialog->set_logo_icon_name('dialog-information');

	# lists of authors and documenters (will be used later)
	my @authors = ('Maximilian Lika');
	my @documenters = ('Maximilian Lika');

	# we fill in the aboutdialog
	$aboutdialog->set_program_name('PLedit');
	$aboutdialog->set_version('0.02');
	$aboutdialog->set_comments("A simple but useful utf8 Texteditor written \n in Perl using Gtk3::SourceView");
	$aboutdialog->set_copyright(
		"Copyright \xa9 2016 Maximilian Lika");
	# important: set_authors and set_documenters need an array ref!
	# with a normal array it doesn't work!	
	$aboutdialog->set_authors(\@authors);
	$aboutdialog->set_documenters(\@documenters);
	my $license = 	"This library is free software; you can redistribute it and/or modify\n". 
					"it under the same terms as Perl itself, either Perl version 5.20.2 \n". 
					"or, at your option, any later version of Perl 5 you may have available.\n".
					"This module is distributed in the hope that it will be useful, but \n".
					"WITHOUT ANY WARRANTY; without even the implied warranty of\n".
					"MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.";
	$aboutdialog->set_license("$license");
	$aboutdialog->set_website('http://github/MaxPerl/PLedit');
	$aboutdialog->set_website_label('GitHub Repository of PLedit');

	# to close the aboutdialog when 'close' is clicked we connect
	# the 'response' signal to on_close
	$aboutdialog->signal_connect('response'=>\&close_about);
	# show the aboutdialog
	$aboutdialog->show();
	}

# destroy the aboutdialog
sub close_about {
	my ($aboutdialog) = @_;
	$aboutdialog->destroy();
	}

