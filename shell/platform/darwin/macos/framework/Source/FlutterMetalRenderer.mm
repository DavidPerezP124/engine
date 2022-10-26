
// Copyright 2013 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#import "flutter/shell/platform/darwin/macos/framework/Source/FlutterMetalRenderer.h"

#import "flutter/shell/platform/darwin/macos/framework/Source/FlutterEngine_Internal.h"
#import "flutter/shell/platform/darwin/macos/framework/Source/FlutterExternalTextureMetal.h"
#import "flutter/shell/platform/darwin/macos/framework/Source/FlutterView.h"
#include "flutter/shell/platform/embedder/embedder.h"

#pragma mark - Static callbacks that require the engine.

static FlutterMetalTexture OnGetNextDrawable(FlutterEngine* engine,
                                             const FlutterFrameInfo* frameInfo) {
  CGSize size = CGSizeMake(frameInfo->size.width, frameInfo->size.height);
  FlutterMetalRenderer* metalRenderer = reinterpret_cast<FlutterMetalRenderer*>(engine.renderer);
  NSLog(@"DebugPrint: OnGetNextDrawable");

  return [metalRenderer createTextureForSize:size];
}

static bool OnPresentDrawable(FlutterEngine* engine, const FlutterMetalTexture* texture) {
  FlutterMetalRenderer* metalRenderer = reinterpret_cast<FlutterMetalRenderer*>(engine.renderer);
    NSLog(@"DebugPrint: OnPresentDrawable");

  return [metalRenderer present:texture->texture_id];
}

static bool OnAcquireExternalTexture(FlutterEngine* engine,
                                     int64_t textureIdentifier,
                                     size_t width,
                                     size_t height,
                                     FlutterMetalExternalTexture* metalTexture) {
  FlutterMetalRenderer* metalRenderer = reinterpret_cast<FlutterMetalRenderer*>(engine.renderer);
  NSLog(@"DebugPrint: OnAcquireExternalTexture");

  return [metalRenderer populateTextureWithIdentifier:textureIdentifier metalTexture:metalTexture];
}

#pragma mark - FlutterMetalRenderer implementation

@implementation FlutterMetalRenderer {
  __weak FlutterEngine* _engine;

  FlutterView* _flutterView;

  FlutterDarwinContextMetal* _darwinMetalContext;
}

int counter;

- (instancetype)initWithFlutterEngine:(nonnull FlutterEngine*)flutterEngine {
  self = [super initWithDelegate:self engine:flutterEngine];
  if (self) {
    _engine = flutterEngine;

    _device = MTLCreateSystemDefaultDevice();
    if (!_device) {
      NSLog(@"Could not acquire Metal device.");
      return nil;
    }

    _commandQueue = [_device newCommandQueue];
    if (!_commandQueue) {
      NSLog(@"Could not create Metal command queue.");
      return nil;
    }
    NSLog(@"DebugPrint: %@", NSStringFromSelector(_cmd));
    _darwinMetalContext = [[FlutterDarwinContextMetal alloc] initWithMTLDevice:_device
                                                                  commandQueue:_commandQueue];
  }
  return self;
}

- (void)setFlutterView:(FlutterView*)view {
  _flutterView = view;
}

- (FlutterRendererConfig)createRendererConfig {
  FlutterRendererConfig config = {
      .type = FlutterRendererType::kMetal,
      .metal.struct_size = sizeof(FlutterMetalRendererConfig),
      .metal.device = (__bridge FlutterMetalDeviceHandle)_device,
      .metal.present_command_queue = (__bridge FlutterMetalCommandQueueHandle)_commandQueue,
      .metal.get_next_drawable_callback =
          reinterpret_cast<FlutterMetalTextureCallback>(OnGetNextDrawable),
      .metal.present_drawable_callback =
          reinterpret_cast<FlutterMetalPresentCallback>(OnPresentDrawable),
      .metal.external_texture_frame_callback =
          reinterpret_cast<FlutterMetalTextureFrameCallback>(OnAcquireExternalTexture),
  };
  NSLog(@"DebugPrint: %@", NSStringFromSelector(_cmd));
  return config;
}



#pragma mark - Embedder callback implementations.

- (FlutterMetalTexture)createTextureForSize:(CGSize)size {
  FlutterMetalRenderBackingStore* backingStore =
      (FlutterMetalRenderBackingStore*)[_flutterView backingStoreForSize:size];
  id<MTLTexture> texture = backingStore.texture;
  FlutterMetalTexture embedderTexture;
  embedderTexture.struct_size = sizeof(FlutterMetalTexture);
  embedderTexture.texture = (__bridge void*)texture;
  embedderTexture.texture_id = reinterpret_cast<int64_t>(texture);
  NSLog(@"DebugPrint: %@", NSStringFromSelector(_cmd));
  return embedderTexture;
}

- (BOOL)present:(int64_t)textureID {
  if (!_flutterView) {
    return NO;
  }
  [_flutterView present];
  FlutterMetalRenderer* __weak weakSelf = self;

  dispatch_async(dispatch_get_main_queue(), ^{
      [weakSelf drawImage];
  });

  return YES;
}

- (void) drawImage {
  NSImage *image = [_flutterView imageRepresentation];
  NSData *imageData = image.TIFFRepresentation;
  NSBitmapImageRep *imageRep = [NSBitmapImageRep imageRepWithData:imageData];
  NSDictionary *imageProps = [NSDictionary dictionaryWithObject:[NSNumber numberWithFloat:1.0] forKey:NSImageCompressionFactor];
  imageData = [imageRep representationUsingType:NSJPEGFileType properties:imageProps];
  NSString *path = [NSString stringWithFormat:@"test%d.jpeg", counter];

  [[NSFileManager defaultManager] createFileAtPath:path contents:nil attributes:nil];
  [imageData writeToFile:path atomically:YES];

  if (counter == 11) {
    counter = 0;
  } else {
    counter++;
  }
}

#pragma mark - FlutterTextureRegistrar methods.

- (BOOL)populateTextureWithIdentifier:(int64_t)textureID
                         metalTexture:(FlutterMetalExternalTexture*)textureOut {
  id<FlutterMacOSExternalTexture> texture = [self getTextureWithID:textureID];
  FlutterExternalTextureMetal* metalTexture =
      reinterpret_cast<FlutterExternalTextureMetal*>(texture);
          NSLog(@"DebugPrint: %@", NSStringFromSelector(_cmd));

  return [metalTexture populateTexture:textureOut];
}

- (id<FlutterMacOSExternalTexture>)onRegisterTexture:(id<FlutterTexture>)texture {
      NSLog(@"DebugPrint: %@", NSStringFromSelector(_cmd));

  return [[FlutterExternalTextureMetal alloc] initWithFlutterTexture:texture
                                                  darwinMetalContext:_darwinMetalContext];
}

@end
