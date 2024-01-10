-------------------------------------------------------------------------------
-- Nodes have an id
--
-- :PROPERTIES:
-- :ID: <ID>
-- :END:
--
-- This can be a file node or headline.
--
-- Other properties (all optional)
-- :ROAM_EXCLUDE: t (if set to non-nil value, does a thing)
-- :ROAM_ALIASES: <text>
-- :ROAM_REFS: <ref>
--
-- Format for refs is one of
--
-- https://example.com (some website)
-- @thrun2005probabilistic (unique citation key)
-- [cite:@thrun2005probabilistic] (org-cite)
-- cite:thrun2005probabilistic (org-ref)

-------------------------------------------------------------------------------
-- CLASS DEFINITIONS
-------------------------------------------------------------------------------

---@class org-roam.Node
---@field title string the title of the org-roam note.
---@field file string the file name where the note is stored.
---@field id string the unique identifier for the note.
---@field level number the heading level of the note in the org-mode file.
---@field tags string[] a list of tags associated with the note.
---@field linked org-roam.Node[] a list of linked notes (references) within the note.

-------------------------------------------------------------------------------
-- VARIABLE DEFINITIONS
-------------------------------------------------------------------------------

---@alias org_roam_completion_everywhere
---| boolean if true, provide link completion matching outside of org links.

---@alias org_roam_dailies_capture_templates
---| table<string, table> mirrors org capture templates, but for org-roam.

---@alias org_roam_dailies_directory
---| string path to daily-notes, relative to org-roam-directory.

---@alias org_roam_db_extra_links_elements
---| {type:'keyword'|'node-property', value:string}[] such as keyword "transclude".

---@alias org_roam_db_extra_links_exclude_keys
---| {type:'keyword'|'node-property', value:string}[] such as node-property "ROAM_REFS".

---@alias org_roam_db_update_on_save
---| boolean if true, updates the database on each save.

---@alias org_roam_graph_edge_extra_config
---| string extra options for edges in the graphviz output (The "E" attributes).

---@alias org_roam_graph_executable
---| string path to graphing executable (in this case, Graphviz).

---@alias org_roam_graph_extra_config
---| string extra options passed to graphviz for the digraph (The "G" attributes).

---@alias org_roam_graph_filetype
---| string file type to generate for graphs (default "svg").

---@alias org_roam_graph_node_extra_config
---| string extra options for nodes in the graphviz output (The "N" attributes).

---@alias org_roam_graph_viewer
---| string path to the program (defaults to browser) to view the SVG.
---| fun(path:string) funtion to be invoked with the file path.

---@alias org_roam_node_display_tempLate
---| string configures display formatting for node.

-------------------------------------------------------------------------------
-- FUNCTION DEFINITIONS
-------------------------------------------------------------------------------

---@alias org_roam_alias_add
---| fun(alias:string) add `alias` to the node at point. If no alias provided, prompts for one.

---@alias org_roam_alias_remove
---| fun() remove an alias from the node at point.

---@alias org_roam_buffer_display_dedicated
---| fun() launches node dedicated buffer without visiting the node itself.

---@alias org_roam_buffer_toggle
---| fun() toggle display of the org roam buffer.

---@alias org_roam_capture_
---| fun() NOT IN USE

---@alias org_roam_dailies_capture_date
---| fun() create an entry in the daily note for a date using the calendar.

---@alias org_roam_dailies_capture_today
---| fun() create an entry in the daily note for today.

---@alias org_roam_dailies_capture_yesterday
---| fun(n:number) create an entry in the daily note for yesterday. If `n` provided, jump to `n` days in the past.

---@alias org_roam_dailies_find_directory
---| fun() finds and opens `org-roam-dailies-directory`. Just a file viewer.

---@alias org_roam_dailies_goto_date
---| fun() find the daily note for a date using the calendar, creating it if necessary.

---@alias org_roam_dailies_goto_next_note
---| fun() when in an daily-note, find the next one.

---@alias org_roam_dailies_goto_previous_note
---| fun() when in an daily-note, find the previous one.

---@alias org_roam_dailies_goto_today
---| fun() find the daily note for today, creating it if necessary.

---@alias org_roam_dailies_goto_yesterday
---| fun(n:number) find the daily note for yesterday, creating it if necessary. If `n` provided, use daily-note `n` days in the future.

---@alias org_roam_graph
---| fun(node:string, n:number) build and display a graph for `node`, or the full graph if `nil`. Will show `n` steps away, or all if `nil`.

---@alias org_roam_node_at_point
---| fun(assert:boolean):org-roam.Node returns the node at point. If `assert` is true, will throw an error if there is no node at point.

---@alias org_roam_node_read
---| fun() TODO: This is one of the most complex, so need time to understand.

---@alias org_roam_ref_add
---| fun(ref:string) add `ref` to the node at point. When `nil`, prompt for the ref to add.

---@alias org_roam_ref_remove
---| fun() remove a ref from the node at point.
