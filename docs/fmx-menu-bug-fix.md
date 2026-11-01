# FMX main menu on Linux: only first letters

On Linux, FMX shows a `TMainMenu` as a native GTK menu bar, and that bar
shows only the first letter of every menu and item: "F" instead of
"File". Windows and macOS are not affected.

> **Status (2026-11-01):** the method was tested in another project
> (Delphi 13, Ubuntu, GTK 3). In TSteamAPI's demos it runs without errors
> on Linux, but nobody has yet confirmed on screen, from a terminal, that
> it shows full names with no `GTK-CRITICAL` lines.

## The fix

Keep designing the `TMainMenu` as usual. On Linux, as the first thing in
`OnCreate`, swap it for an FMX `TMenuBar` holding copies of its items:

```pascal
uses
  FmxLinuxMenu;

procedure TForm1.FormCreate(Sender: TObject);
begin
  ReplaceMainMenu(Self, MainMenu1);   // FIRST; does nothing off Linux
  // ... the rest of OnCreate
end;
```

The unit is `FmxLinuxMenu.pas`; there are identical copies in
`demos/SteamInputDemo/src`, `demos/VirtualGamepad/src` and
`RemoteLogging/LogReceiver/src`. The core of it:

```pascal
{$IF defined(LINUX) and not defined(ANDROID)}
function ReplaceMainMenu(AForm: TCommonCustomForm; var AMenu: TMainMenu): TMenuBar;
begin
  Result := TMenuBar.Create(AForm);
  Result.Parent := AForm;
  Result.Position.Y := -1;            // above any other top-aligned control
  Result.Align := TAlignLayout.Top;
  // 1. COPY every item (and its submenus) onto the menu bar:
  //    Text, Enabled, Visible, IsChecked, ShortCut, OnClick, ...
  // 2. Empty the TMainMenu ONE ITEM AT A TIME, so GTK's bar goes too
  while AMenu.ItemsCount > 0 do
    AMenu.Items[0].Free;
  AMenu.RecreateOSMenu;
  FreeAndNil(AMenu);
  // 3. Give each copy its original's Name: the form's published fields
  //    (mnuFile, mnuExit, ...) then point at the copies
end;
{$ENDIF}
```

## What does not work

- **Moving the original items to a `TMenuBar`** crashes in libgobject or
  floods the terminal with `GTK-CRITICAL` warnings: the items still
  belong to GTK widgets.
- **Freeing the `TMainMenu` with its items still in it** leaves GTK's bar
  on screen.

## Rules

- Call it before any code touches a menu item, and keep no reference to
  a designed item from before the call: those items are freed.
  References through the form's fields work, because the copies take
  over the names.
- Add items at run time only after the call.
- The copies get `Text`, `Enabled`, `Visible`, `AutoCheck`, `IsChecked`,
  `RadioItem`, `GroupIndex`, `ShortCut`, `Tag` and `OnClick`. If a menu
  uses anything else (an image, say), add it to `CopyItem`.
- On SteamOS every main window is full screen, so add a way to reach
  important commands that doesn't depend on the menu (SteamInputDemo
  uses a controller button combination).
