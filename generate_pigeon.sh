echo "Generating Pigeon code"

# Generate Dart, IOS and Android code
dart run pigeon --input pigeon/volume_button_listener.dart\
  --dart_out lib/src/volume_button_listener.g.dart \
  --kotlin_out android/src/main/kotlin/com/navideck/volume_button_listener/VolumeButtonListener.g.kt \
  --kotlin_package com.navideck.volume_button_listener \
  --swift_out ios/volume_button_listener/Sources/volume_button_listener/VolumeButtonListener.g.swift \
  --cpp_header_out windows/volume_button_listener.g.h \
  --cpp_source_out windows/volume_button_listener.g.cpp \
  --cpp_namespace volume_button_listener

# Generate MacOS code
dart run pigeon --input pigeon/volume_button_listener.dart\
  --swift_out macos/volume_button_listener/Sources/volume_button_listener/VolumeButtonListener.g.swift 


# Windows
# dart run pigeon --input pigeon/volume_button_listener.dart --cpp_header_out windows/volume_button_listener.g.h --cpp_source_out windows/volume_button_listener.g.cpp --cpp_namespace volume_button_listener 

