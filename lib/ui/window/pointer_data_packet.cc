// Copyright 2013 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#include "flutter/lib/ui/window/pointer_data_packet.h"

#include <cstring>

namespace flutter {

PointerDataPacket::PointerDataPacket(size_t count)
    : data_(count * sizeof(PointerData)) {}

PointerDataPacket::PointerDataPacket(uint8_t* data, size_t num_bytes)
    : data_(data, data + num_bytes) {}

PointerDataPacket::~PointerDataPacket() = default;

void PointerDataPacket::SetPointerData(size_t i, const PointerData& data) {
    fprintf(stderr, ">>> type %lld date: %lld location: x: %f y: %f, synth: %lld, rds_max: %f, ptr_id: %lld\n", data.change, data.time_stamp, data.physical_x,data.physical_y, data.synthesized, data.radius_max, data.pointer_identifier);

  memcpy(&data_[i * sizeof(PointerData)], &data, sizeof(PointerData));
}

}  // namespace flutter
