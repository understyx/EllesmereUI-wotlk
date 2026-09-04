# Retail/Midnight vs. WotLK UI visual differences

## Purpose

This document records visible differences between the Retail/Midnight reference UI and the current WotLK 3.3.5 implementation of EllesmereUI. It also identifies changes that can make the WotLK version feel substantially closer to Retail without pretending that both clients expose the same systems or data.

**Status:** Future work and design reference. This document does not describe changes that have already been implemented.

For brevity, **Retail** below means the Midnight-era Retail reference shown in the supplied screenshots.

The observations currently cover:

- Character sheet
- Inspect
- Dungeon Finder
- Player vs. Player and Battlegrounds
- Reputation
- Currency
- Mounts
- Mail
- Achievements
- Friends/Contacts
- Who

The screenshots were captured at different window sizes and UI scales. Their raw pixel dimensions should therefore **not** be treated as exact measurements. The useful reference is the relative spacing, hierarchy, alignment, and visual weight within each window.

## Target and constraints

The goal should be **Retail visual language with WotLK-correct behavior**.

That means:

- Reproduce Retail's layout hierarchy, spacing, typography, surfaces, controls, and selection treatments where practical.
- Keep WotLK-only information when it remains useful, even if Retail no longer presents it.
- Do not display controls for unsupported Retail systems unless the addon implements real behavior behind them.
- Do not fake unavailable stats, Renown levels, mount metadata, flight styles, or other modern-client data.
- Prefer one coherent shared window style over isolated screen-specific imitations.

## Cross-screen differences

| Area | Retail/Midnight reference | Current WotLK version | Recommended direction |
| --- | --- | --- | --- |
| Window hierarchy | Strong header, content surface, and footer/tab separation | Inconsistent: some custom pages blend together while others retain native metal/parchment layers | Define a shared shell with distinct header, body, and footer regions |
| Titles | Uses a context-specific title: page name, character name, or BattleTag depending on the window | Several skinned sub-pages continue showing the parent window's title | Set the centered title deliberately for each page rather than inheriting it accidentally |
| Typography | Larger and heavier labels with clear size tiers | Hierarchy varies; dense lists often use smaller, quieter text while native pages retain ornate serif text | Establish shared title, section, row, value, and secondary-text styles |
| Content density | Roomy rows and larger interaction targets | Dense, table-like native rows | Increase row height and internal padding; avoid stretching content merely to fill the window |
| Panels | Warm translucent surfaces over the background artwork | Mix of very dark custom surfaces and untouched native parchment/metal | Use a warm dark translucent surface consistently, with restrained one-pixel borders |
| Section headers | Full-width bands with strong labels and right-aligned `+`/`-` controls | Small text headers or thin table separators | Introduce a reusable full-width accordion header |
| Selection | Clearly filled selection with an accent border/glow | Muted fill or narrow indicator | Use one shared selected-row treatment with accent-colored edge or glow |
| Scroll bars | Simple track and thumb with minimal chrome | Legacy framed bars with separate arrow buttons | Restyle to a plain Retail-like track and thumb where the native widget permits it |
| Tabs | Broad rectangular blocks integrated into the footer | Treatment varies between modernized blocks and smaller native tabs | Standardize height, padding, typography, and active-state treatment |
| Accent color | Used deliberately for the active state and key values | Some screens use different hard-coded highlight colors | Use the configured EllesmereUI accent consistently rather than screen-specific colors |
| Icons | Clean crops, consistent sizing, restrained borders | Size and border treatment vary by screen | Reuse one icon crop, border, and quality-color treatment |
| Empty space | Intentional and balanced around primary content | Some pages leave large unused regions below dense lists | Let the content surface breathe, but size/reflow major regions to avoid accidental dead space |

## Character sheet

### Observed differences

- Retail gives the character model and both equipment columns more horizontal room.
- Retail equipment icons and item-level labels are visually larger.
- Retail shows several item-level quality colors and small upgrade/socket indicators beside equipped items.
- The WotLK example shows predominantly purple item levels and does not show the same adjacent markers.
- Retail displays two item-level values (`178.00 / 183.06` in the reference), while WotLK displays one average value (`269.41`). The screenshots do not label the precise meaning of the Retail pair.
- Retail has a more distinct header band below the character identity.
- Retail uses larger tab labels and a stronger active tab block.
- Stat categories reflect different game systems:
  - Retail: Attributes, Secondary, Tertiary, Attack
  - WotLK: Attributes, Melee, Ranged, Spell, Defense
- The actual stats differ as well. Retail includes Mastery, Versatility, Leech, Avoidance, and Speed; WotLK includes Armor Penetration, Expertise, separate spell stats, and other expansion-appropriate values.
- Retail shows three small square utility icons at the lower-right of the character area; their exact function is not identifiable from the screenshot. The WotLK example does not show them.
- WotLK retains Character, Pets, Reputation, Skills, and Currency navigation, while Retail exposes fewer tabs in this window.

### Recommended changes

High-value visual changes:

1. Increase the visual breathing room between the equipment columns, character model, and stat panel.
2. Make the equipment icons, item levels, and slot-to-label spacing match the Retail proportions more closely.
3. Add a clear header/body boundary and align the title, level, and specialization text as a deliberate header stack.
4. Use a consistent footer tab height and a stronger filled active state.
5. Normalize the stat-pane typography: larger category headings, stronger numeric values, quieter row labels, and consistent row spacing.
6. Align category rules, chevrons, labels, and values to a common grid.
7. Keep quality-colored item borders and item-level text, but ensure their saturation and line thickness match the Retail reference.
8. Preserve the existing socket/enchant indicators where WotLK data is available; refine their size and offset to resemble Retail's compact equipment annotations.

Keep WotLK semantics:

- Retain Melee, Ranged, Spell, and Defense groupings unless a redesigned grouping remains accurate for every class.
- Keep Pets and Skills accessible. Hiding them solely to match Retail would remove useful WotLK navigation.
- Keep a single equipped average item level unless a second value can be calculated reliably and explained correctly.
- Do not add Mastery, Versatility, or Tertiary stats to a client that does not provide them.

Likely implementation area: `EllesmereUIBlizzardSkin/EllesmereUIBlizzardSkin_CharacterSheet.lua`.

## Inspect

### Character/equipment view: observed differences

- Retail shows the inspected character name, level, specialization, and class as a centered header stack. WotLK shows the name plus level/race/class, but has no specialization line because that metadata is not exposed in the same form.
- Retail displays the inspected average item level prominently beneath the identity header. It is absent in the WotLK reference.
- Retail uses a shorter, more tightly composed equipment/model area. WotLK leaves a large vertical gap between the character model and the weapon row.
- Retail's equipment icons, item-level labels, quality colors, and small upgrade/socket annotations match the main Retail character sheet.
- The WotLK item levels are almost entirely purple in the reference and do not show the same adjacent annotations.
- Retail has two contextual actions at the bottom of the character pane: Transmog and Talents.
- Retail's primary Inspect navigation is Character, PvP, and Guild.
- WotLK's primary Inspect navigation is Character, PvP, and Talents. It exposes the legacy talent inspection tree as a full embedded tab.
- WotLK has an expansion-specific ranged/relic weapon slot in the lower equipment row. This produces three bottom slots instead of Retail's two and should be preserved.
- Both versions already use a similar left equipment column, central model, right equipment column, and lower weapon strip, so the basic composition is reusable.

### Talent inspection: current defects and platform difference

- The WotLK Talent tab is a core inspection feature and should remain available as a permanent tab.
- Its current problems are presentation defects rather than a failure of the overall feature:
  - Talent icons are missing, leaving empty dark squares.
  - Rank text is clipped down to small fragments near the button edges.
  - Talent buttons and the tree are sized and positioned awkwardly within the much larger Inspect window.
- Tree selection, point totals, dependency arrows, scrolling, and the underlying inspection flow otherwise appear to work.
- Midnight does not expose talent inspection as the same kind of permanent third Inspect tab.
- Although the Retail reference contains a `Talents` contextual action, that is not a direct visual reference for an embedded WotLK-style talent-tree page.
- The permanent tab should therefore be treated as an intentional WotLK-specific feature inside an otherwise Retail-like Inspect shell.

### Recommended changes

Character/equipment view:

1. Reduce the unused vertical gap and bring the weapon row closer to the model composition.
2. Add inspected item level when it can be calculated reliably from equipped items.
3. Match the main character sheet's slot sizing, icon crops, quality borders, item-level typography, and annotations.
4. Keep the third WotLK ranged/relic slot and center the three-slot weapon row as an expansion-appropriate variation.
5. Match Retail's header spacing and visual hierarchy while retaining WotLK-correct identity text.
6. Move optional actions into contextual buttons above the primary footer rather than adding more permanent footer tabs.

Talent inspection:

- Keep Talents as the permanent third WotLK Inspect tab.
- Restore every talent icon and rank label.
- Resize and center the talent tree so it makes deliberate use of the available body area.
- Scale talent buttons, dependency arrows, tree tabs, and the scroll bar as one coordinated layout rather than adjusting isolated elements.
- Preserve the working tree selection, point totals, dependency arrows, and scrolling behavior.
- Keep all tree content and its scroll bar within the Inspect body.
- Verify that opening and closing Talent inspection does not disturb the Character or PvP layouts.

Client limitations:

- WotLK cannot provide Retail's exact specialization, transmog, and modern talent metadata.
- Transmog is not a native WotLK system and should not be shown unless the target server/addon provides a real equivalent.
- Retail's Guild tab should not replace a functional WotLK feature unless corresponding inspect guild data and content actually exist.
- The permanent WotLK talent tree is a compatibility feature, not a one-to-one Midnight reproduction.

Likely implementation area: `EllesmereUIBlizzardSkin/EllesmereUIBlizzardSkin_InspectSheet.lua`, especially the legacy `SkinInspectTalents` and Inspect tab-visibility logic.

## Dungeon Finder

### Observed differences

- Midnight presents Dungeon Finder inside a large `Dungeons & Raids` window using the shared dark shell, centered title, and simple close icon.
- WotLK presents Dungeon Finder as a much smaller floating native panel. Much of the world remains visible through or around the content, so the controls do not read as one contained window.
- Midnight uses a left category rail for Dungeon Finder, Raid Finder, and Premade Groups.
- WotLK does not have equivalent versions of every modern category; its related secondary action is Raid Browser.
- Midnight places role controls in a clear horizontal group at the top of the content pane.
- WotLK uses similar role icons, but they float near the top without the same header/content structure.
- Both versions use a Type dropdown followed by the selected activity's description and rewards.
- Midnight places the primary `Find Group` action centered at the bottom of the content pane.
- WotLK places `Find Group` and `Raid Browser` as competing actions at opposite lower corners.
- Midnight's reward presentation is more compact and card-like. WotLK uses smaller native panels and older typography.

### Recommended changes

1. Use the Midnight `Dungeons & Raids` composition as the primary visual target.
2. Contain all WotLK Dungeon Finder controls within the shared dark shell and content surface.
3. Reuse the large left navigation rail, but include only real WotLK destinations such as Dungeon Finder and Raid Browser.
4. Keep role selection, Type, description, rewards, and queue behavior native while restyling and repositioning them.
5. Present `Find Group` as the primary centered action.
6. Move Raid Browser into the left rail instead of leaving it as a competing red button.
7. Use the shared dropdown, reward card, money display, primary button, footer, and close-button styles.
8. Do not create decorative Raid Finder, Premade Groups, or Mythic+ destinations when the WotLK client/server does not implement them.

Likely implementation area: `EllesmereUIBlizzardSkin/EllesmereUIBlizzardSkin_GroupFinder.lua`.

## Player vs. Player and Battlegrounds

Neither WotLK page has a direct Midnight equivalent with matching information architecture. These screens should preserve their WotLK functionality while borrowing visual components from existing EllesmereUI pages.

### PvP summary: observed differences

- WotLK's PvP page uses an ornate native metal frame, character portrait, red close button, and dark embossed background.
- The top summary contains Honor, Arena points, and Today/Yesterday/Lifetime kill and honor statistics.
- The lower area contains large 2v2, 3v3, and 5v5 arena-team panels.
- PvP and Battlegrounds are permanent footer tabs.
- There is no strong Midnight page reference containing this same set of WotLK-era PvP and arena-team information.

### PvP summary: recommended direction

Use the existing **Inspect PvP tab** as the direct styling reference:

1. Reuse its dark stats-card surfaces, typography, dividers, label/value hierarchy, spacing, and arena-team card treatment.
2. Keep the full WotLK Honor, Arena, Today, Yesterday, Lifetime, and 2v2/3v3/5v5 data model.
3. Replace the portrait, metal frame, embossed artwork, and red close button with the shared EllesmereUI shell.
4. Use `Player vs. Player` as the centered page title.
5. Keep PvP and Battlegrounds as permanent footer tabs with the shared active-tab treatment.
6. Factor the Inspect PvP visual components into reusable helpers if practical so the two screens cannot drift stylistically.

### Battleground queue: observed differences

- WotLK's Battlegrounds page contains functionality with no close Midnight equivalent:
  - A selectable list containing Random Battleground, Call to Arms, individual battlegrounds, and Wintergrasp information.
  - A selected-battleground description.
  - Separate win and loss reward rows.
  - Join as Party, Join Battle, and Cancel actions.
- The current page is dominated by native parchment, map, metal, portrait, scroll-bar, and red-button artwork.
- The list, detail panel, and actions are useful and should not be removed merely because Midnight structures PvP queues differently.

### Battleground queue: provisional recommended direction

Use a **modernized WotLK layout**, not an invented Midnight copy:

1. Keep Battlegrounds as the second permanent tab beside PvP.
2. Apply the same outer shell, header, footer, and typography as the PvP summary page.
3. Replace the parchment/map list with a dark bordered list using flat selectable rows and a clear accent selection.
4. Present Wintergrasp and other queue timing information in a compact right-aligned header/status area.
5. Present the selected battleground name, description, and Rewards in one dark detail card.
6. Restyle Win and Loss as simple reward rows with aligned icons and values.
7. Put Join as Party, Join Battle, and Cancel in one consistent bottom action row, preserving disabled states and queue restrictions.
8. Use the shared minimal scroll bar and button treatments.
9. Avoid adding modern rated/unrated category rails unless the WotLK data and queue actions genuinely support them.

This direction is intentionally provisional. It gives the Battleground page a coherent EllesmereUI appearance without falsely claiming a one-to-one Midnight reference.

Client limitations:

- WotLK Honor/Arena summaries and arena teams do not map cleanly to Midnight's current PvP systems.
- Wintergrasp, Call to Arms, win/loss rewards, and party queue restrictions must retain their original behavior.
- Queue buttons and selection state are functional controls; styling must not alter protected or disabled behavior.

Likely implementation areas:

- `EllesmereUIBlizzardSkin/EllesmereUIBlizzardSkin_GroupFinder.lua` for shared group/PvP shell work where applicable
- A dedicated WotLK PvP/Battleground skin may be clearer if these legacy frames are not owned by the existing Group Finder path

## Reputation

### Observed differences

- Retail titles the window `Reputation`; WotLK continues to show the character name.
- Retail has an `All` filter dropdown in the upper-right.
- Retail groups reputations by expansion in wide accordion sections.
- WotLK uses smaller faction-group labels with expand/collapse controls on the left.
- Retail does not need explicit `Faction` and `Standing` column headings; layout communicates the columns visually.
- Retail places each faction name and its progress bar in a spacious two-column row.
- Retail supports Renown, friendship levels, and traditional standings in the same list.
- WotLK shows traditional standing bars only.
- Retail bars use flatter fills and integrated labels. WotLK bars have stronger gradients and inset framing.
- Retail uses a minimal scroll bar; WotLK uses a framed legacy scroll bar with arrow buttons.
- The WotLK page leaves a large unused area below the visible rows.

### Recommended changes

High-value visual changes:

1. Use `Reputation` as the page title while this tab is active.
2. Convert native faction headers into wide accordion-style bands with the control on the right.
3. Remove or visually de-emphasize the `Faction` and `Standing` column headings.
4. Increase row height and inset faction names from the left edge.
5. Give standing bars a consistent width, flatter fill, subdued background, and centered label.
6. Replace the visually heavy scroll bar chrome with the shared minimal treatment.
7. Reflow the list vertically so the page feels intentionally composed even when few factions are visible.

Optional, only if functional:

- Add a filter for WotLK-relevant groups such as All, Classic, The Burning Crusade, Wrath of the Lich King, and Inactive.
- A filter should be backed by real faction metadata or an explicit addon mapping. A decorative dropdown that does nothing should not be added.

Client limitation:

- WotLK does not have Retail Renown or the same expansion-category data model. The native hierarchy can be styled like Retail, but it cannot be made semantically identical without maintaining addon-owned grouping data.

Likely implementation areas:

- `EllesmereUIBlizzardSkin/EllesmereUIBlizzardSkin_CharacterSheet.lua`
- `EllesmereUIBlizzardSkin/Skins/Character.lua` for the fallback/non-themed skin

## Currency

### Observed differences

- Retail titles the window `Currency`; WotLK continues to show the character name.
- Retail includes a character-specific dropdown and a small utility button near it.
- Retail uses large accordion categories and may contain nested groups.
- WotLK uses thin, centered category rows and presents all visible currencies in a dense table.
- Retail places the currency name on the left and its quantity/icon on the right.
- WotLK places quantity first, followed by the icon and name.
- Retail category labels are large and yellow with right-aligned `+`/`-` controls.
- WotLK category labels are smaller and white with a left-side indicator.
- Retail provides much more row spacing.
- WotLK shows the player's gold, silver, and copper at the lower-left; Retail does not show money in this panel.
- The WotLK screenshot contains an additional red-and-gold close-style button near the top-right that does not belong to the Retail composition.

### Recommended changes

High-value visual changes:

1. Use `Currency` as the active page title.
2. Convert category rows to the same wide accordion component used by Reputation.
3. Rebuild the visual order of currency rows as name on the left, then quantity and icon on the right.
4. Increase row height, but keep the list compact enough to remain useful with WotLK's longer flat currency lists.
5. Use larger, consistently cropped icons with a restrained one-pixel border.
6. Remove the extra top-right close-style control from the main composition; expose its action in a clearer contextual control if the behavior is still required.
7. Keep the money display, but reduce its prominence and align it cleanly with the content/footer grid.
8. Apply the shared minimal scroll bar and shared footer-tab treatment.

Optional, only if functional:

- Add an All/character filter if WotLK data provides a meaningful distinction.
- Nested groups should only be introduced when the underlying currencies can be categorized reliably.

Client limitation:

- Midnight categories such as Delves and seasonal currency groups do not exist in WotLK. The WotLK categories should retain their own names and data while adopting the Retail presentation.

Likely implementation areas:

- `EllesmereUIBlizzardSkin/EllesmereUIBlizzardSkin_CharacterSheet.lua`
- `EllesmereUIBlizzardSkin/Skins/Character.lua` for the fallback/non-themed skin

## Mounts

### Observed differences

- Retail uses a large collections-style window; WotLK embeds Mounts in the smaller character/Pets window.
- Retail has dedicated Search and Filter controls; WotLK has Search only.
- Retail shows a prominent total-mount count.
- Retail rows have separate large icons and roomy name panels.
- Retail uses a bright accent border/glow for the selected mount.
- WotLK uses a muted pink selection fill and narrow side indicator.
- Retail's detail pane shows the mount icon, name, acquisition source, location, flavor text, and a large character-on-mount preview.
- WotLK's detail pane primarily contains the mount model.
- Retail has a `Show Character` toggle.
- Retail includes Flight Style, Summon Random Favorite Mount, and Mount Equipment controls.
- WotLK provides a single `Summon` button.
- Retail switches collection types using its collections navigation; WotLK uses Companions/Mounts sub-tabs and the main Pets tab.

### Recommended changes

High-value visual changes:

1. Expand the Mounts layout within safe WotLK frame constraints and give the list/detail split more room.
2. Match Retail's list styling: larger icons, taller rows, consistent gutters, and a clear accent selection.
3. Add a detail header containing the selected mount icon and name above the model preview.
4. Place the Summon action consistently at the lower-right of the detail pane and style it like the shared primary button.
5. Increase the size of the model viewport and use the same warm translucent surface as other pages rather than a plain black field.
6. Standardize the Companions/Mounts sub-tabs with the main footer-tab visual language.
7. Keep Search and improve its padding, font, and focus state.

Possible addon-owned enhancements:

- A basic filter could distinguish ground and flying mounts if that information can be derived reliably.
- Favorites and random-favorite summoning could be implemented through addon-maintained saved data.
- `Show Character` may be possible if the WotLK model widget can display the rider and mount together reliably; it needs an in-client prototype before becoming a documented requirement.

Client limitations:

- WotLK does not provide the modern Mount Journal's complete source, location, flavor-text, mount-equipment, and flight-style data.
- Do not show empty Retail fields. If optional addon-maintained metadata is not available, keep the detail header and model and omit the unsupported rows.
- A pixel-identical Retail collections window would require a custom replacement interface rather than a skin of the native WotLK companion page.

Likely implementation areas:

- `EllesmereUIBlizzardSkin/EllesmereUIBlizzardSkin_CharacterSheet.lua` for the current themed companion/mount panel
- `EllesmereUIBlizzardSkin/Skins/Character.lua` for the fallback/non-themed skin
- A separate custom module if the Mounts page grows beyond reskinning the native companion UI

## Mail

### Inbox: observed differences

- Retail uses a large dark window with the shared warm background, simple centered title, and white close icon.
- WotLK uses the native compact metal frame, parchment list, circular mail portrait, and red-and-gold close button.
- Retail presents six large full-width message rows with thin borders and a uniform dark fill.
- WotLK presents seven shorter parchment rows with a dedicated square icon area at the left.
- Both references show an empty mailbox, so sender, subject, money, attachment, read/unread, and expiration treatments cannot yet be compared.
- Retail places previous/next navigation in simple square buttons at the lower corners.
- WotLK uses labeled `Prev` and `Next` controls with heavier arrow-button artwork.
- Retail provides a large centered `Open All` action. The native WotLK reference does not.
- Retail's Inbox and Send Mail tabs are broad footer blocks with a thin accent active state.
- WotLK's tabs are smaller, use native beveled artwork, and sit partly outside the ornamental frame.

### Send Mail: observed differences

- Retail keeps the parchment writing surface but surrounds it with the shared dark EllesmereUI shell.
- WotLK surrounds the same basic parchment surface with dense metal, scroll, and inset artwork.
- Retail uses larger and cleaner To and Subject fields with more open spacing around the Postage value.
- WotLK fields use heavy native framing and are packed tightly into the header.
- Retail's message parchment is wider and does not show the visually heavy native side scroll frame in the reference.
- Both versions provide seven attachment slots, but Retail uses flat dark squares while WotLK uses ornate recessed slots and native placeholder artwork.
- Retail gives the amount fields, Send Money/C.O.D. controls, player-money display, and Send/Cancel actions more horizontal room.
- WotLK compresses the same controls into a smaller footer with multiple nested borders.
- Retail integrates Send and Cancel as equal-height rectangular actions. WotLK retains beveled native button artwork and a red Cancel treatment.
- Retail uses the same simple footer tabs as Inbox; WotLK continues the native tab style.

### Recommended changes

Shared mail shell:

1. Remove the circular portrait, metal frame, red close-button art, parchment list surround, and native footer-tab artwork.
2. Apply the shared EllesmereUI header, background, border, close icon, content surface, and footer tabs.
3. Use the active page name (`Inbox` or `Send Mail`) as the centered title.
4. Keep all mailbox behavior and state owned by the native WotLK mail frames; replace presentation rather than message logic.

Inbox:

1. Restyle inbox messages as full-width dark rows with consistent padding and restrained borders.
2. Preserve sender, subject, money, attachment, read/unread, and expiration information once populated; arrange it within the larger Retail-like row instead of discarding it.
3. Replace the Prev/Next labels and ornate buttons with simple arrow controls while retaining WotLK pagination.
4. Add `Open All` only if it is backed by a reliable event-driven collection workflow.
5. An Open All implementation must stop safely for full bags, C.O.D. mail, inventory errors, server throttling, and messages requiring user decisions.

Send Mail:

1. Retain the parchment compose surface as a deliberate exception within the dark shell; it is present in both references.
2. Flatten and align the To and Subject fields, keeping Postage right-aligned in the same header grid.
3. Restyle attachment slots using the shared square icon-slot treatment while preserving drag, drop, tooltip, and removal behavior.
4. Simplify the amount fields and Send Money/C.O.D. controls without changing their meaning.
5. Align the player's money display and Send/Cancel actions to a clean bottom grid.
6. Restyle the message scroll bar minimally rather than removing it if long WotLK mail still requires scrolling.

Client limitations:

- Open All is not merely visual. It should not be displayed until its WotLK behavior is safe and complete.
- Mail interaction can be server-throttled and has stateful attachment/money rules; cosmetic work must not bypass native protections or error handling.
- The populated Inbox requires additional references before its internal information hierarchy can be matched confidently.

Likely implementation area: a dedicated Mail skin in `EllesmereUIBlizzardSkin`. Mail appears in the skin options, but no dedicated Mail skin file is currently present in the module.

## Achievements

### Observed differences

- Retail uses the same dark, warm, translucent window language as the other references. WotLK retains the native ornate metal frame and parchment background almost completely.
- Retail displays `Warband Achievement Points` in a separate dark summary block above the main window. WotLK embeds character achievement points into the ornamental top frame.
- Retail uses a simple white close icon. WotLK uses the native red-and-gold close button.
- Retail provides Back and Search controls in the header. Neither control is present in the WotLK summary reference.
- Retail's category list uses flat dark rows, white text, subtle separators, and a light filled selection.
- WotLK's category list uses beveled brown buttons, yellow text, glow effects, and a green selected state.
- Retail includes modern categories such as Characters, Housing, Delves, Pet Battles, Collections, Expansion Features, and Legacy.
- WotLK has its expansion-appropriate category set, including General and Feats of Strength, and does not have the modern systems.
- Retail's recent-achievement rows use flat charcoal cards with the icon at left, centered title/description, date at right, and the point shield at the far edge.
- WotLK's recent-achievement rows use parchment cards, red/brown outlines, serif text, and native gold shield artwork.
- Retail shows three recent achievements in the reference; WotLK shows four. This is a content-density choice rather than a required system difference.
- Retail progress bars use neutral gray tracks, bright cyan fills, large bold labels, and a simple two-column grid.
- WotLK progress bars use dark beveled frames, green fills, yellow labels, and heavier ornamental borders.
- Retail gives the overall `Achievements Earned` bar its own full-width row, followed by category bars.
- WotLK uses the same hierarchy, but the native ornamentation makes every bar visually heavy.
- Retail's lower navigation contains Achievements, Guild, and Statistics. WotLK contains Achievements and Statistics because guild achievements are not part of the WotLK system.

### Recommended changes

This page needs a full visual reskin rather than small native-frame adjustments:

1. Suppress the parchment, carved-metal frame, native header ornament, and red close-button artwork.
2. Apply the shared EllesmereUI window shell, background artwork, dark overlay, close icon, and footer treatment.
3. Restyle the category list as flat full-width rows with a clear neutral/accent selected state.
4. Rebuild the recent-achievement presentation as dark cards with consistent icon sizing, title/description hierarchy, right-aligned date, and point badge.
5. Restyle all progress bars with flat tracks, configured-accent fills, one-pixel borders, and consistent value alignment.
6. Use the Retail content hierarchy: recent achievements first, a full-width overall progress bar, then the two-column category overview.
7. Increase internal padding and reduce ornamental visual weight so labels and progress become the focus.
8. Keep Achievements and Statistics as the WotLK footer tabs and style them consistently with the other EllesmereUI windows.
9. Keep the WotLK category names and counts; only their presentation should mimic Retail.

Possible addon-owned enhancements:

- A Search field could scan WotLK achievement names and descriptions if the client API exposes enough achievement data. It should only be shown after a reliable search workflow exists.
- A Back button is useful only if a custom category/detail navigation layer creates a real history state.
- The number of recent achievements could be reduced to three for closer composition matching, but four can remain if the page still feels balanced.

Client limitations:

- WotLK achievement points are character-era data, not Warband-wide data. Label the total `Achievement Points`; do not imitate the `Warband` wording.
- Modern categories and Guild Achievements should not be added when their underlying systems do not exist.
- Retail's exact achievement badges and some newer metadata may not be available. Existing WotLK point/date data can still be arranged in the Retail layout.

Likely implementation area: a dedicated achievement skin in `EllesmereUIBlizzardSkin`. The window is listed in the skin options, but no dedicated Achievement skin file is currently present in the module.

## Friends/Contacts and Who

### Friends/Contacts: observed differences

- Retail displays the player's BattleTag as the window title; the WotLK version displays `Friends`.
- Retail removes the circular portrait and all legacy metal header artwork. Those elements remain visible and overlap the upper-left of the WotLK window.
- Retail separates its title from the body with a simple horizontal rule.
- Retail uses a wide `Invite Friend...` field. WotLK also has an invite field, but status controls and legacy framing compete with it visually.
- Retail provides Friends, Recent, Recruit, and Ignore sub-tabs on one line.
- WotLK exposes Friends and Ignore as smaller legacy-style tabs.
- Retail places chat and online-status controls at the right of the sub-tab row.
- Retail friend rows use large icons, two clearly separated text lines, generous padding, and a strong blue selected state.
- WotLK's selected row is directionally similar, but the list is narrower and the remaining rows use weaker contrast and hierarchy.
- WotLK shows legacy online dots beside rows; Retail uses richer status, game, faction, and platform indicators.
- Both references leave unused list space when few friends are present. In WotLK, native status/game icons are stranded in that empty area instead of remaining attached to a clearly structured row or footer.
- Retail aligns `Add Friend` and `Send Message` as equal-height footer actions. WotLK uses similar actions, but their accent, width, and surrounding spacing are inconsistent.
- Retail's main navigation includes Contacts, Who, Raid, and Quick Join. The WotLK reference only exposes Friends and Who.

### Who: observed differences

- Retail keeps the same BattleTag header, modern sub-tabs, body surface, and bottom navigation used by Contacts.
- WotLK retains the legacy portrait, stone/metal title bar, framed content artwork, and old buttons inside the EllesmereUI outer shell.
- Retail uses a clean header row with Name, Level, and Class columns and subtle vertical dividers.
- WotLK includes a Zone dropdown among the column headers and uses older compact column styling.
- Retail places `0 People Found` immediately above a wide search field near the bottom of the list surface.
- WotLK places the result count above the legacy button area and does not present the query field as part of a clean modern footer.
- Retail uses a minimal scroll thumb inside the right edge of the results pane.
- WotLK retains thin legacy scroll tracks along the content edges.
- Retail aligns Refresh, Add Friend, and Group Invite in a three-column action row.
- In the WotLK reference, the action row is clipped and shifted left: part of the Refresh button is outside the window.
- A large opaque horizontal black band cuts across the middle of the WotLK Who pane. This is a layout/rendering defect, not merely a stylistic difference.
- WotLK's content and controls do not align to the outer EllesmereUI frame, producing mixed coordinate systems and overlapping visual layers.

### Recommended changes

Correctness fixes should come first:

1. Remove the horizontal black obstruction from the WotLK Who page.
2. Keep the full Who content, scroll area, search controls, count, and action buttons inside one clipped content surface.
3. Anchor the three Who actions to the actual content bounds so Refresh is never off-screen.
4. Remove or fully suppress the legacy portrait, title bar, metal borders, and button-strip artwork after the page loads.
5. Verify that Friends and Who reuse the same window coordinate system when switching tabs and after reopening the frame.

High-value visual changes:

1. Use the BattleTag as the shared window title when Battle.net data is available, with `Friends` as the fallback.
2. Add the simple title divider and use identical header height across Contacts and Who.
3. Standardize the main navigation tabs, sub-tabs, content insets, scroll bars, and bottom actions across both pages.
4. Make the friends list a single continuous surface; remove stray background breaks and floating native artwork.
5. Refine friend rows to match Retail's icon size, two-line type hierarchy, padding, separators, and selected-state contrast.
6. Present the Who query field as a wide bottom search box with the result count directly above it.
7. Use subtle column dividers and align every result row to the same Name, Level, and Class grid.
8. Keep Zone as a functional WotLK filter, but present it as an optional filter control rather than allowing its native chrome to dominate the column header.
9. Apply the configured accent consistently to the active tab and primary enabled action. Disabled actions should remain visibly subdued.

Keep WotLK semantics:

- Do not create nonfunctional Recent, Recruit, Raid, or Quick Join pages merely to reproduce Retail's navigation count.
- Keep Ignore accessible even if it must remain a WotLK-specific sub-tab arrangement.
- Preserve the Zone query/filter capability because it is useful in the WotLK Who workflow.
- Retail Battle.net presence details may not all exist in the WotLK API; show only status and metadata that can be determined reliably.

Likely implementation area: `EllesmereUIFriends/EllesmereUIFriends.lua`.

## Recommended implementation order

### Phase 0: critical layout correctness

The Who layout and Inspect Talent presentation contain visible failures, so these should precede broader polish.

1. Fix the Who page's black obstruction and conflicting native layers.
2. Contain the Who result pane, query field, count, and action row within stable bounds.
3. Keep the Inspect Talent tab available while repairing its icon rendering, rank labels, sizing, and centering.
4. Re-test tab switching, reopening, UI scaling, and empty/results-populated states.

### Phase 1: shared visual system

This produces the broadest improvement and prevents each page from drifting into a different style.

1. Define shared page-title behavior.
2. Define shared header, body surface, and footer geometry.
3. Define typography tiers and reusable colors.
4. Define shared accordion headers, list rows, selected rows, icons, scroll bars, buttons, and tabs.
5. Replace hard-coded selection colors with the configured EllesmereUI accent.

### Phase 2: Dungeon Finder and WotLK PvP

These screens establish how the project handles WotLK workflows that do not map exactly to Midnight.

1. Bring Dungeon Finder into the shared Dungeons & Raids shell and move Raid Browser into its category rail.
2. Restyle the PvP summary using the Inspect PvP tab as its component reference.
3. Apply the provisional modernized-WotLK treatment to the Battleground queue without changing its workflow.
4. Verify every queue, role, selection, disabled, party, and cancel state before completion.

### Phase 3: Achievements

Achievements is currently one of the most visually native WotLK windows and therefore one of the largest gains after the shared components exist.

1. Replace the native shell and parchment surfaces.
2. Restyle category rows and recent-achievement cards.
3. Apply the shared progress-bar and footer-tab components.
4. Validate Summary, category detail, and Statistics before considering the skin complete.

### Phase 4: Mail

Mail already has a clear Retail reference and preserves a parchment compose surface, so it can closely match Retail without replacing its native workflow.

1. Replace the native window shell and footer tabs.
2. Restyle empty and populated Inbox rows plus pagination.
3. Restyle Send Mail fields, attachment slots, money controls, and actions.
4. Treat Open All as a separate behavioral enhancement with dedicated safety testing.

### Phase 5: Reputation and Currency

These pages can gain most of the Retail appearance without requiring modern game systems.

1. Apply the shared accordion headers.
2. Reflow list rows and values.
3. Restyle progress bars and icons.
4. Correct active page titles.
5. Clean up scroll bars and empty-space balance.

### Phase 6: Character sheet refinement

1. Refine proportions and equipment-slot spacing.
2. Improve the title/level/spec header stack.
3. Normalize item-level and annotation placement.
4. Refine stat-row typography and alignment.
5. Unify the bottom navigation with other sub-pages.

### Phase 7: Mounts

1. First match the Retail composition using only existing WotLK data.
2. Prototype any rider preview, filtering, favorites, or metadata features separately.
3. Only retain enhancements that behave reliably on the 3.3.5 client.

## Suggested acceptance criteria

- All documented screens visibly belong to the same UI family without relying on different one-off styles.
- Opening a CharacterFrame sub-page changes the centered title to that page's name.
- Header, content, and footer boundaries align consistently across Character, Reputation, and Currency.
- Accordion headers, list rows, selected states, icons, scroll bars, and tabs use shared styling.
- Friends and Who share one stable geometry, with no native artwork leaking through or controls extending outside the window.
- Inspect retains its permanent WotLK Talent tab with correctly rendered icons, readable ranks, and intentional sizing.
- Dungeon Finder is contained within a coherent Dungeons & Raids shell while retaining WotLK queue behavior.
- The standalone PvP summary visually matches Inspect PvP, and Battlegrounds retains its permanent tab and full WotLK workflow.
- Achievements no longer exposes native parchment or ornamental frame pieces when its EllesmereUI skin is enabled.
- Inbox and Send Mail share the EllesmereUI shell while preserving all native mail actions and state.
- No useful WotLK-only navigation or data is removed merely to imitate Retail.
- No unsupported Retail control is visible unless it performs a real action.
- Layout remains usable at the supported UI scales and with long localized text.
- Changes are verified in game on every affected page before completion.

## Further comparisons to capture

The following references would make later implementation decisions more precise:

- Hover, pressed, focused, and disabled states for tabs and buttons
- Expanded and collapsed Reputation/Currency headers
- Reputation row selection and detail popup
- Currency row selection and tracking/backpack popup
- Mount list scrolling, filtering, unavailable mounts, and summon states
- Character sheet at minimum and maximum supported UI scale
- Friends list with online, offline, Battle.net, and in-game friends
- Friends list with enough entries to require scrolling
- Who page with no results and with a full page of results
- Who queries using the Zone filter and free-text search
- Friends-to-Who tab switching before and after resizing or changing UI scale
- Achievement Summary, individual category, and Statistics pages
- Achievements with long titles/descriptions and completed/incomplete states
- Achievement tooltips, tracked achievements, and earned-achievement notifications
- Inspect Character and PvP pages for every class
- Inspect with empty slots, dual wield, two-handed weapons, and the WotLK ranged/relic slot
- Inspect Talent data before arrival, after arrival, with dual specialization, and when unavailable
- Inspect contextual Talents/Transmog actions on clients or servers where those features differ
- Inbox populated with read, unread, returned, C.O.D., money-only, attachment, and expiring mail
- Inbox pagination and a full mailbox
- Send Mail with long recipient/subject text, all attachment slots, money, and C.O.D.
- Mail error states, full bags, disconnects, and server throttling before any Open All feature is accepted
- Dungeon Finder with each role combination, random/specific dungeon selection, rewards, queueing, and Raid Browser
- PvP summary with empty and populated 2v2/3v3/5v5 arena teams
- Battleground selection, Wintergrasp timing, Call to Arms, random and specific queues, and win/loss rewards
- Battleground Join Battle, Join as Party, disabled, queued, and cancel states
- Long names and non-English locales
- Empty, partially populated, and fully populated equipment slots
