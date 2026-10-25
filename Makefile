TARGET = libBundleRedirector.dylib
CC = clang
CFLAGS = -dynamiclib -arch arm64 -isysroot $(shell xcrun --sdk iphoneos --show-sdk-path) -miphoneos-version-min=12.0 -fobjc-arc
LDFLAGS = -framework Foundation

all: $(TARGET)

$(TARGET): hook.m
	$(CC) $(CFLAGS) $(LDFLAGS) hook.m -o $(TARGET)
	codesign -s - --entitlements entitlements.plist $(TARGET)

clean:
	rm -f $(TARGET)TARGET = libBundleRedirector.dylib
CC = clang
CFLAGS = -dynamiclib -arch arm64 -isysroot $(shell xcrun --sdk iphoneos --show-sdk-path) -miphoneos-version-min=12.0 -fobjc-arc
LDFLAGS = -framework Foundation

all: $(TARGET)

$(TARGET): hook.m
	$(CC) $(CFLAGS) $(LDFLAGS) hook.m -o $(TARGET)
	codesign -s - --entitlements entitlements.plist $(TARGET)

clean:
	rm -f $(TARGET)
