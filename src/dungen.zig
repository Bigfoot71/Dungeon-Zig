const std = @import("std");
const Allocator = std.mem.Allocator;
const RndGen = std.rand.DefaultPrng;

pub const Map = struct {
    allocator: *Allocator,
    array: []i8,
    width: u16,
    height: u16,

    pub fn getFromInt(self: *const Map, px: i32, py: i32) i8 {
        if (px >= 0 and py >= 0) {
            const x: u32 = @intCast(px);
            const y: u32 = @intCast(py);
            return self.array[y * self.width + x];
        }
        return 0;
    }

    pub fn getFromFloat(self: *const Map, px: f32, py: f32) i8 {
        if (px >= 0 and py >= 0) {
            const x: u32 = @intFromFloat(px + 0.5);
            const y: u32 = @intFromFloat(py + 0.5);
            return self.array[y * self.width + x];
        }
        return 0;
    }
};

// BSP subdivision de l'espace, afin de generé un donjon de pièces reliés entre elles
fn walkDungeon(rnd: *RndGen, map_array: []i8, x1: u16, y1: u16, x2: u16, y2: u16, width: u16, min_width: u16) void {
    const stop_width: u32 = min_width * 2 + 1;

    const w: u16 = x2 - x1 + 1;
    const h: u16 = y2 - y1 + 1;

    // Width subdivision
    if (w >= h and w >= stop_width) {
        const x: u16 = x1 + min_width + (rnd.random().int(u16) % (x2 - x1 - 2 * min_width + 1));

        var y: u16 = y1;
        while (y <= y2) : (y += 1) {
            const ptr: *i8 = &map_array[y * width + x];
            if (ptr.* == 0) ptr.* = 1;
        }

        // Add door Randomly, account for
        // walls placed deeper into recursion
        const door_y: u16 = y1 + 1 + rnd.random().int(u16) % (y2 - y1 - 1);

        map_array[door_y * width + x] = -1;
        map_array[door_y * width + (x - 1)] = -1;
        map_array[door_y * width + (x + 1)] = -1;

        walkDungeon(rnd, map_array, x1, y1, x - 1, y2, width, min_width);
        walkDungeon(rnd, map_array, x + 1, y1, x2, y2, width, min_width);
    }
    // Height subdivision
    else if (h >= stop_width) {
        const y: u16 = y1 + min_width + (rnd.random().int(u16) % (y2 - y1 - 2 * min_width + 1));

        var x: u16 = x1;
        while (x <= x2) : (x += 1) {
            const ptr: *i8 = &map_array[y * width + x];
            if (ptr.* == 0) ptr.* = 1;
        }

        // Add door Randomly, account for
        // walls placed deeper into recursion
        const door_x: u16 = x1 + 1 + rnd.random().int(u16) % (x2 - x1 - 1);

        map_array[y * width + door_x] = -1;
        map_array[(y - 1) * width + door_x] = -1;
        map_array[(y + 1) * width + door_x] = -1;

        walkDungeon(rnd, map_array, x1, y1, x2, y - 1, width, min_width);
        walkDungeon(rnd, map_array, x1, y + 1, x2, y2, width, min_width);
    }
}

pub fn init(allocator: *Allocator, rnd: *RndGen, width: u16, height: u16) !Map {
    const w: u16 = width * 2 + 1;
    const h: u16 = height * 2 + 1;

    var map_array = try allocator.alloc(i8, w * h);
    @memset(map_array, @as(i8, 0));

    // Fill the walls of the edges of the map
    var y: u16 = 0;
    while (y < h) : (y += 1) {
        map_array[y * w] = 1;
        map_array[y * w + w - 1] = 1;
    }
    var x: u16 = 0;
    while (x < w) : (x += 1) {
        map_array[x] = 1;
        map_array[(w - 1) * w + x] = 1;
    }

    // Generation of room walls/doors
    walkDungeon(rnd, map_array, 1, 1, w - 2, h - 2, w, 4);

    return Map{
        .allocator = allocator,
        .array = map_array,
        .width = w,
        .height = h,
    };
}

pub fn deinit(self: *Map) void {
    self.allocator.free(self.array);
}
