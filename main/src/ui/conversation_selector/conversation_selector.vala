using Gee;
using Gtk;

using Xmpp;
using Dino.Entities;

namespace Dino.Ui {

public class ConversationSelector : ListBox {

    public signal void conversation_selected(Conversation conversation);

    private StreamInteractor stream_interactor;
    private string[]? filter_values;
    private HashMap<Conversation, ConversationSelectorRow> rows = new HashMap<Conversation, ConversationSelectorRow>(Conversation.hash_func, Conversation.equals_func);
    private Viewport? viewport;
    private ScrolledWindow? scrolledwindow;
    private Window window;
    private Adjustment vadj;

    public ConversationSelector init(StreamInteractor stream_interactor, Window window) {
        this.stream_interactor = stream_interactor;
        this.window = window;

        viewport = this.get_parent() as Viewport;
        if (viewport != null) {
            scrolledwindow = viewport.get_parent() as ScrolledWindow;
            if (scrolledwindow != null) {
                vadj = scrolledwindow.get_vadjustment();
            }
        }

        stream_interactor.get_module(ConversationManager.IDENTITY).conversation_activated.connect(add_conversation);
        stream_interactor.get_module(ConversationManager.IDENTITY).conversation_deactivated.connect(remove_conversation);
        stream_interactor.get_module(MessageProcessor.IDENTITY).message_received.connect(on_message_received);
        stream_interactor.get_module(MessageProcessor.IDENTITY).message_sent.connect(on_message_received);
        Timeout.add_seconds(60, () => {
            foreach (ConversationSelectorRow row in rows.values) row.update();
            return true;
        });

        foreach (Conversation conversation in stream_interactor.get_module(ConversationManager.IDENTITY).get_active_conversations()) {
            add_conversation(conversation);
        }
        return this;
    }

    construct {
        this.stream_interactor = stream_interactor;

        get_style_context().add_class("sidebar");
        set_filter_func(filter);
        set_header_func(header);
        set_sort_func(sort);

        realize.connect(() => {
            ListBoxRow? first_row = get_row_at_index(0);
            if (first_row != null) {
                select_row(first_row);
                row_activated(first_row);
            }
        });
    }

    public override void row_activated(ListBoxRow r) {
        ConversationSelectorRow? row = r as ConversationSelectorRow;
        if (row != null) {
            conversation_selected(row.conversation);
            scroll_viewport(row);
        }
    }

    private void scroll_viewport(ConversationSelectorRow row) {
        if (scrolledwindow != null) {
            int row_x;
            int row_y;
            row.translate_coordinates(this, 0, 0, out row_x, out row_y);
            int row_bottom = row_y + row.get_allocated_height();
            double y = vadj.value;
            double bottom = y + vadj.page_size;

            if (row_y < y) {
                vadj.set_value((double)row_y);
            } else {
                vadj.set_value((double)row_bottom - vadj.page_size);
            }
        }
    }

    public void set_filter_values(string[]? values) {
        if (filter_values == values) {
            return;
        }
        filter_values = values;
        invalidate_filter();
    }

    public void on_conversation_selected(Conversation conversation) {
        if (!rows.has_key(conversation)) {
            add_conversation(conversation);
        }
        this.select_row(rows[conversation]);
    }

    private void on_message_received(Entities.Message message, Conversation conversation) {
        if (rows.has_key(conversation)) {
            invalidate_sort();
        }
    }

    private void add_conversation(Conversation conversation) {
        ConversationSelectorRow row;
        if (!rows.has_key(conversation)) {
            row = new ConversationSelectorRow(stream_interactor, conversation);
            rows[conversation] = row;
            add(row);
            row.closed.connect(() => { select_fallback_conversation(conversation); });
            row.main_revealer.set_reveal_child(true);
        }
        invalidate_sort();
    }

    private void select_fallback_conversation(Conversation conversation) {
        if (get_selected_row() == rows[conversation]) {
            int index = rows[conversation].get_index();
            ListBoxRow? next_select_row = get_row_at_index(index + 1);
            if (next_select_row == null) {
                next_select_row = get_row_at_index(index - 1);
            }
            if (next_select_row != null) {
                select_row(next_select_row);
                row_activated(next_select_row);
            }
        }
    }

    private void remove_conversation(Conversation conversation) {
        select_fallback_conversation(conversation);
        if (rows.has_key(conversation) && !conversation.active) {
            remove(rows[conversation]);
            rows.unset(conversation);
        }
    }

    public void loop_conversations(bool backwards) {
        int index = get_selected_row().get_index();
        int new_index = ((index + (backwards ? -1 : 1)) + rows.size) % rows.size;
        ListBoxRow? next_select_row = get_row_at_index(new_index);
        if (next_select_row != null) {
            select_row(next_select_row);
            row_activated(next_select_row);
        }
    }

    private void header(ListBoxRow row, ListBoxRow? before_row) {
        if (row.get_header() == null && before_row != null) {
            row.set_header(new Separator(Orientation.HORIZONTAL));
        } else if (row.get_header() != null && before_row == null) {
            row.set_header(null);
        }
    }

    private bool filter(ListBoxRow r) {
        ConversationSelectorRow? row = r as ConversationSelectorRow;
        if (row != null) {
            if (filter_values != null && filter_values.length != 0) {
                foreach (string filter in filter_values) {
                    if (!(Util.get_conversation_display_name(stream_interactor, row.conversation).down().contains(filter.down()) ||
                            row.conversation.counterpart.to_string().down().contains(filter.down()))) {
                        return false;
                    }
                }
            }
        }
        return true;
    }

    private int sort(ListBoxRow row1, ListBoxRow row2) {
        ConversationSelectorRow cr1 = row1 as ConversationSelectorRow;
        ConversationSelectorRow cr2 = row2 as ConversationSelectorRow;
        if (cr1 != null && cr2 != null) {
            Conversation c1 = cr1.conversation;
            Conversation c2 = cr2.conversation;
            if (c1.last_active == null) return -1;
            if (c2.last_active == null) return 1;
            int comp = c2.last_active.compare(c1.last_active);
            if (comp == 0) {
                return Util.get_conversation_display_name(stream_interactor, c1)
                    .collate(Util.get_conversation_display_name(stream_interactor, c2));
            } else {
                return comp;
            }
        }
        return 0;
    }
}

}
