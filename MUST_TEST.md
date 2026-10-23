# SideHome: Must Test

A checklist for testing SideHome on a real iPhone. Go through it top to bottom and tick what works. For anything that doesn't, note the **number** (for example `4.3`), what you expected, what actually happened, and a screenshot if you can. SHDebug's **Log** section (at the bottom of SHDebug) is the most useful screenshot.

> Nothing here has been tested on a real device yet. Every item could be broken, which is what this list is for.

---

## 0. Install or update

- [ ] **0.1** On the iPhone, download [SideHome.ipa](https://github.com/oneauragottermed/SideHome/releases/download/nightly/SideHome.ipa) in Safari.
- [ ] **0.2** In SideStore → My Apps → **+** → pick `SideHome.ipa` → choose **Keep App Extensions**. LocalDevVPN must be on.
- [ ] **0.3** An update keeps your apps, folders and wallpaper (SHDebug is still there after updating).
- [ ] **0.4** First install only: Settings (gear in the dock) → Advanced → LiveContainer Settings → **Import Certificate From SideStore**.
- [ ] **0.5** Download [SHDebug.ipa](https://github.com/oneauragottermed/SideHome/releases/download/shdebug/SHDebug.ipa), then in SideHome tap **Install IPA** (blue icon in the dock) and pick it. To get the new SHDebug buttons, install it again over the old one ("replace" when asked).
- [ ] **0.6** Optional but useful: install one more IPA (any app you like) so the app switcher has two cards.

## 1. Home screen

- [ ] **1.1** The SideHome icon (white tiles and a grey dock on graphite) shows on the real iPhone home screen. Also check it in dark mode and with tinted icons. If it's blank white after updating, restart the iPhone (iOS caches icons).
- [ ] **1.2** Inside SideHome: a plain dark wallpaper, your apps in a grid, a round glass button at the bottom left, a **Search** pill, and a glass dock with Settings and Install IPA.
- [ ] **1.7** SHDebug shows its own icon (green `>_` on black) instead of a blank white one. Reinstall SHDebug to get it.
- [ ] **1.3** Long-press an app → menu with App Settings, Add to Folder, Edit Home Screen and Delete App.
- [ ] **1.4** Edit Home Screen → icons wiggle → a **Done** button appears at the top right → Done stops the wiggling.
- [ ] **1.5** Long-press and drag an icon onto another to swap places. The order stays after closing and reopening SideHome.
- [ ] **1.6** App Settings opens LiveContainer's per-app settings in a sheet, with **Done** to close.

## 2. Opening apps

- [ ] **2.1** Tap SHDebug → it grows out of its icon to full screen.
- [ ] **2.2** Swipe up from the **very bottom edge** → the app shrinks back into its icon. The first swipe goes to SideHome; a second one leaves to real iOS. That's on purpose.
- [ ] **2.3** Tap SHDebug again → it comes back as you left it, without restarting. The "Launch #" number doesn't go up.
- [ ] **2.4** Rotate the phone inside SHDebug. Note what happens.

## 2b. Navigation island (Back · Home · Forward)

- [ ] **2b.1** Open an app → a glass island with Back, Home and Forward appears at the bottom middle by itself.
- [ ] **2b.2** Home → the app shrinks back into its icon and the island disappears.
- [ ] **2b.3** On the home screen, the round glass button (bottom left) shows and hides the island. When shown there, it sits just above the dock.
- [ ] **2b.4** Open app A, go home, open app B, then press **Back** → app A. Press **Forward** → app B. Back from the first app → home screen.
- [ ] **2b.5** Back and Forward are greyed out when there's nowhere to go.
- [ ] **2b.6** Home also closes Settings, Notification Center, Control Center, Search and the LiveContainer screens.
- [ ] **2b.7** The island doesn't block taps on the app when it's hidden.

## 3. App switcher

- [ ] **3.1** Inside SHDebug: swipe up from the bottom, **pause** for a moment, then lift → the app turns into a card on a blurred background.
- [ ] **3.2** On the home screen: swipe **up on the dock** → the app switcher opens (only when an app is running).
- [ ] **3.3** Tap a card → that app opens full-screen.
- [ ] **3.4** Swipe a card **up** → it flies away and the app quits. The "Launch #" goes up next time you open it.
- [ ] **3.5** Tap the empty background → back to the home screen.
- [ ] **3.6** With two apps running: swipe left and right to move between cards. The most recent app is in the middle and older ones are to the left.

## 4. Notifications (use SHDebug)

- [ ] **4.1** **Ask Notification Permission** → iOS asks "SideHome would like to send you notifications" → Allow → the log says "granted".
- [ ] **4.2** **Notify Now** while SHDebug is open → a glass banner drops from the top with **SHDebug's icon** and title. It hides after about 5 seconds.
- [ ] **4.3** Swipe the banner up → it goes away. Tap a banner → SHDebug opens.
- [ ] **4.4** **Notify in 10 s**, then go back to SideHome's home screen → the banner appears over the home screen.
- [ ] **4.5** **Notify in 60 s**, then leave SideHome completely (swipe up to the iOS home screen) → a real iOS notification appears, titled "SHDebug" with the message under it and SHDebug's icon as a small picture.
- [ ] **4.6** Tap that real notification → SideHome opens and launches SHDebug.
- [ ] **4.7** Same as 4.5, but lock the phone → it shows on the lock screen.
- [ ] **4.8** **Notify with Long Text** → the banner cuts the text off neatly after a few lines.
- [ ] **4.9** **Set Random Badge** → a red number appears on SHDebug's icon in SideHome, and the SideHome icon on the iOS home screen shows the same number.
- [ ] **4.10** **Clear Badge** → both badges disappear.

## 5. Notification Center

- [ ] **5.1** **Notify 3 Times** in SHDebug and wait a few seconds.
- [ ] **5.2** On SideHome's home screen, swipe **down from the top-left corner** (start on the clock) → SideHome's Notification Center drops down with the date and a big clock.
- [ ] **5.3** It lists the notifications with SHDebug's icon and "x min" times.
- [ ] **5.4** Tap a notification → it closes and SHDebug opens.
- [ ] **5.5** **Clear All** empties the list.
- [ ] **5.6** Swipe up from the bottom edge → Notification Center closes.
- [ ] **5.7** Inside SHDebug, swipe down from the top-left → Notification Center opens over the app.
- [ ] **5.8** A second swipe down from the top while SideHome's is open → iOS's own Notification Center.

## 6. Control Center

- [ ] **6.1** Swipe **down from the top-right corner** (start on the battery) → SideHome's Control Center.
- [ ] **6.2** The brightness slider (tall, with a sun) changes the real screen brightness.
- [ ] **6.3** The volume slider changes the real volume.
- [ ] **6.4** Flashlight turns the torch on and off.
- [ ] **6.5** The "Glass" button cycles Clear → Tinted → Off, and the dock's look changes to match.
- [ ] **6.6** App Switcher opens the switcher. Close All Apps quits every running app.
- [ ] **6.7** Tap empty space, or swipe up from the bottom → it closes.
- [ ] **6.8** It also opens from inside SHDebug (swipe down from the top-right).

## 7. Search

- [ ] **7.1** Tap the **Search** pill → a search screen with the keyboard already up.
- [ ] **7.2** Type `shd` → SHDebug shows. Tap it → SHDebug opens.
- [ ] **7.3** Type something that matches nothing → "No Results". **Cancel** closes it.

## 8. Folders

- [ ] **8.1** Long-press SHDebug → Add to Folder → **New Folder…** → type a name → Create → a glass folder icon with a tiny SHDebug inside takes its place.
- [ ] **8.2** Tap the folder → it opens with a blurred background and its name above. Tap outside → it closes.
- [ ] **8.3** Tap the app inside the folder → it opens.
- [ ] **8.4** Long-press the app inside the folder → **Remove from Folder** → it goes back to the home screen, and the empty folder disappears.
- [ ] **8.5** With a second app installed: Add to Folder lists your existing folder, and the folder icon shows both mini icons.
- [ ] **8.6** Long-press a folder → Rename Folder works, and **Remove Folder** puts its apps back on the home screen.
- [ ] **8.7** A badge on an app inside a folder shows on the folder icon.
- [ ] **8.8** Folders survive closing and reopening SideHome.

## 9. Settings app

- [ ] **9.1** Tap the grey gear → Settings zooms out of the icon.
- [ ] **9.2** Swipe up from the bottom edge (or down from the top) → it closes back into the icon.
- [ ] **9.3** Wallpaper → Choose a New Wallpaper → pick a photo → the preview and home screen change. Use Default Wallpaper resets it.
- [ ] **9.4** Liquid Glass → Clear / Tinted / Off changes the preview dock and the real dock.
- [ ] **9.5** Home Screen → Show App Names off hides icon labels.
- [ ] **9.6** Advanced → App Library, LiveContainer Settings, Tweaks and Sources each open LiveContainer's screen, and the **Home** button at the top brings you back.
- [ ] **9.7** About shows the version and app count, and both links open.

## 10. Installing and deleting

- [ ] **10.1** Install IPA → the file picker opens right away.
- [ ] **10.2** While installing, an "Installing…" icon with a progress ring appears, then turns into the app.
- [ ] **10.3** Installing an app that's already installed asks whether to replace it.
- [ ] **10.4** Long-press → Delete App → confirm → the icon disappears (also from folders).

## 11. SHDebug buttons that failed before

For each one, press it once, then screenshot SHDebug's Log, and SideHome's **Settings → Advanced → Debug Log** (it lists every notification, badge, haptic and URL SideHome received from apps; **Copy** copies it).

- [ ] **11.1** Haptic: Success / Impact / Selection. Do you **feel** anything now? Also try Settings → Advanced → Debug Log → **Test SideHome Haptic**. Does the log list "Haptic …" lines after pressing SHDebug's buttons?
- [ ] **11.2** Run 30 s Background Task, then go to SideHome's home screen for 30 s and come back. Do the ticks say "background" or "foreground"?
- [ ] **11.3** Open shdebug:// (own URL scheme) → SHDebug's log should add "Opened via URL: shdebug://hello". SideHome's Debug Log shows "URL … delivered".
- [ ] **11.4** Copy Text to Clipboard, then Paste from Clipboard. Does it show the text?
- [ ] **11.5** The keyboard field: does the keyboard appear? Can you type?
- [ ] **11.6** Crash the App: what happens? (Black screen? Back to the home screen? Frozen?)
- [ ] **11.7** "Ran X s of Y s": leave SHDebug on SideHome's home screen for 1 minute, then reopen. Write down both numbers. Then do the same after leaving SideHome to the iOS home screen.
- [ ] **11.8** Still working? Camera and Photos permission, Dark Mode, Show Alert, Pick a File, Open apple.com.

---

## Known limits (not bugs)

- **Push notifications from servers** (WhatsApp, Discord…) can't work in SideHome or LiveContainer. Only notifications an app schedules itself work.
- When SideHome is closed, its apps are paused too. Notifications they already scheduled still arrive.
- Real iOS notifications always show **SideHome's** icon on the left; the app's icon is the small picture on the right.
- The first swipe from the top or bottom edge goes to SideHome, and the second one goes to iOS.
- Permissions (camera, photos…) are shared by all apps inside SideHome.
- App switcher cards don't show the app's name or icon above them yet.
- Impact haptics from apps always play at medium strength (the app's chosen strength is private to iOS).

## How to report

One line per bug works best:

```
4.2 – banner didn't appear, log says "Scheduled …" (screenshot)
8.1 – folder created but icon is empty
```
