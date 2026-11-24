# Protocol and platform references

- Apple, `IOHIDUserDeviceCreateWithProperties`: the SDK header documents the
  `com.apple.developer.hid.virtual.device` requirement.
  https://developer.apple.com/documentation/bundleresources/entitlements/com.apple.developer.hid.virtual.device
- Apple, creating virtual HID devices:
  https://developer.apple.com/documentation/corehid/creatingvirtualdevices
- Sony, supported controllers and Remote Play on Mac:
  https://www.playstation.com/en-us/remote-play/
- Sony, PS Remote Play controls and setup on Mac:
  https://remoteplay.dl.playstation.net/remoteplay/lang/en/1100002.html
- Linux `hid-playstation`, used as a cross-check for DS4 report sizes, field
  layout, status bits, and feature reports:
  https://github.com/torvalds/linux/blob/master/drivers/hid/hid-playstation.c

DualShock, DualSense, PlayStation, and PS Remote Play are trademarks of Sony
Interactive Entertainment. InputBridge is independent and is not endorsed by
Sony or Apple.
