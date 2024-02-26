const std = @import("std");
const Allocator = std.mem.Allocator;
const RndGen = std.rand.DefaultPrng;

const rl = @cImport(@cInclude("raylib.h"));
const dungen = @import("dungen");

const SCREEN_WIDTH = 800;
const SCREEN_HEIGHT = 600;

const App = struct {
    model: rl.Model,
    camera: rl.Camera3D,
    diffuse: rl.Texture,
    specular: rl.Texture,
    normal: rl.Texture,
    shader: rl.Shader,
    map: dungen.Map,
    locViewLightPos: i32,

    pub fn init(allocator: *Allocator, rnd: *RndGen) !App {
        var self: App = undefined;

        // Load light shader
        self.shader = rl.LoadShader("resources/shader/light.vs", "resources/shader/light.fs");
        self.locViewLightPos = rl.GetShaderLocation(self.shader, "viewLightPos");

        // Generate dungeon map buffer
        self.map = try dungen.init(allocator, rnd, 32, 32);

        // Generate map model
        self.model = genMapModel(&self.map);

        // Load model textures
        self.diffuse = loadTexture("resources/images/Diffuse.png");
        self.specular = loadTexture("resources/images/Specular.png");
        self.normal = loadTexture("resources/images/Normal.png");

        // Set textures and shader to the map model
        self.model.materials[0].maps[rl.MATERIAL_MAP_DIFFUSE].texture = self.diffuse;
        self.model.materials[0].maps[rl.MATERIAL_MAP_SPECULAR].texture = self.specular;
        self.model.materials[0].maps[rl.MATERIAL_MAP_NORMAL].texture = self.normal;
        self.model.materials[0].shader = self.shader;

        // Init Camera3D
        self.camera = rl.Camera3D{
            .position = rl.Vector3{ .x = 1.5, .y = 0.5, .z = 1.5 },
            .target = rl.Vector3{ .x = 2.0, .y = 0.5, .z = 2.0 },
            .up = rl.Vector3{ .x = 0.0, .y = 1.0, .z = 0.0 },
            .fovy = 60.0,
            .projection = rl.CAMERA_PERSPECTIVE,
        };

        // App init finished!
        return self;
    }

    pub fn deinit(self: *App) void {
        rl.UnloadTexture(self.normal);
        rl.UnloadTexture(self.specular);
        rl.UnloadTexture(self.diffuse);
        rl.UnloadModel(self.model);
        dungen.deinit(&self.map);
        rl.UnloadShader(self.shader);
    }

    pub fn updateAndDraw(self: *App) void {
        rl.BeginDrawing();
        defer rl.EndDrawing();

        rl.ClearBackground(rl.BLACK);

        // Performance of vectorization not tested,
        // just put it there for the fun of Zig
        var dir = @Vector(2, f32){ 0.0, 0.0 };
        if (rl.IsKeyDown(rl.KEY_W)) dir[0] += 1;
        if (rl.IsKeyDown(rl.KEY_S)) dir[0] -= 1;
        if (rl.IsKeyDown(rl.KEY_D)) dir[1] += 1;
        if (rl.IsKeyDown(rl.KEY_A)) dir[1] -= 1;

        if (dir[0] != 0 or dir[1] != 0) {
            const mag = @sqrt(dir[0] * dir[0] + dir[1] * dir[1]);
            const invMag = if (mag > 0) 1.0 / mag else 1.0;
            const speed = 1.5 * rl.GetFrameTime();
            dir *= @splat(invMag * speed);
        }

        rl.UpdateCameraPro(&self.camera, rl.Vector3{
            .x = dir[0],
            .y = dir[1],
            .z = 0.0,
        }, rl.Vector3{
            .x = rl.GetMouseDelta().x * 0.05,
            .y = rl.GetMouseDelta().y * 0.05,
            .z = 0.0,
        }, rl.GetMouseWheelMove());

        if (wallCollision(&self.camera, &self.map)) {
            _ = wallCollision(&self.camera, &self.map);
        }

        const viewLightPos: [3]f32 = .{ self.camera.position.x, self.camera.position.y, self.camera.position.z };
        rl.SetShaderValue(self.shader, self.locViewLightPos, &viewLightPos, rl.SHADER_UNIFORM_VEC3);

        rl.BeginMode3D(self.camera);
        rl.DrawModel(self.model, rl.Vector3{ .x = 0.0, .y = 0.0, .z = 0.0 }, 1.0, rl.WHITE);
        rl.EndMode3D();
    }
};

fn genMapModel(map: *dungen.Map) rl.Model {
    var image = rl.GenImageColor(map.width, map.height, rl.BLACK);
    defer rl.UnloadImage(image);

    for (map.array, 0..) |value, i| {
        if (value == 1) {
            var x: i32 = @intCast(i % map.width);
            var y: i32 = @intCast(i / map.width);
            rl.ImageDrawPixel(&image, x, y, rl.WHITE);
        }
    }

    var mesh = rl.GenMeshCubicmap(image, rl.Vector3{ .x = 1.0, .y = 1.0, .z = 1.0 });
    rl.GenMeshTangents(&mesh);

    return rl.LoadModelFromMesh(mesh);
}

fn loadTexture(filePath: [*c]const u8) rl.Texture {
    var texture = rl.LoadTexture(filePath);
    rl.SetTextureFilter(texture, rl.TEXTURE_FILTER_BILINEAR);
    rl.GenTextureMipmaps(&texture);
    return texture;
}

fn wallCollision(camera: *rl.Camera3D, map: *const dungen.Map) bool {
    const pos_2d = rl.Vector2{ .x = camera.position.x, .y = camera.position.z };
    const rd_pos_2d = rl.Vector2{ .x = @round(pos_2d.x), .y = @round(pos_2d.y) };

    const max_x: f32 = @min(rd_pos_2d.x + 1, @as(f32, @floatFromInt(map.width)) - 1);
    const max_y: f32 = @min(rd_pos_2d.y + 1, @as(f32, @floatFromInt(map.height)) - 1);

    const cam_rect = rl.Rectangle{ .x = pos_2d.x - 0.2, .y = pos_2d.y - 0.2, .width = 0.4, .height = 0.4 };
    var result_disp = rl.Vector2{ .x = 0, .y = 0 };

    var y: f32 = @max(rd_pos_2d.y - 1, 0);
    while (y <= max_y) : (y += 1) {
        var x: f32 = @max(rd_pos_2d.x - 1, 0);
        while (x <= max_x) : (x += 1) {
            if ((x != rd_pos_2d.x or y != rd_pos_2d.y) and map.getFromFloat(x, y) == 1) {
                const tile_rect = rl.Rectangle{ .x = x - 0.5, .y = y - 0.5, .width = 1.0, .height = 1.0 };

                const dist = rl.Vector2{ .x = pos_2d.x - x, .y = pos_2d.y - y };
                const min_dist = rl.Vector2{ .x = (cam_rect.width + tile_rect.width) * 0.5, .y = (cam_rect.height + tile_rect.height) * 0.5 };

                var collision_vector = rl.Vector2{ .x = 0, .y = 0 };

                if (@fabs(dist.x) < min_dist.x and @fabs(dist.y) < min_dist.y) {
                    const overlap = rl.Vector2{
                        .x = min_dist.x - @fabs(dist.x),
                        .y = min_dist.y - @fabs(dist.y),
                    };
                    if (overlap.x < overlap.y) {
                        collision_vector.x = if (dist.x > 0) overlap.x else -overlap.x;
                    } else {
                        collision_vector.y = if (dist.y > 0) overlap.y else -overlap.y;
                    }
                }

                if (@fabs(collision_vector.x) > @fabs(result_disp.x)) result_disp.x = collision_vector.x;
                if (@fabs(collision_vector.y) > @fabs(result_disp.y)) result_disp.y = collision_vector.y;
            }
        }
    }

    const adx = @fabs(result_disp.x);
    const ady = @fabs(result_disp.y);

    if (adx > ady) {
        camera.position.x += result_disp.x;
        camera.target.x += result_disp.x;
    } else {
        camera.position.z += result_disp.y;
        camera.target.z += result_disp.y;
    }

    return (adx > 0 and ady > 0);
}

pub fn main() !void {
    var allocator = std.heap.page_allocator;

    const seed: u64 = @intCast(std.time.milliTimestamp());
    var rnd = std.rand.DefaultPrng.init(seed);

    // Init window and OpenGL context
    rl.InitWindow(SCREEN_WIDTH, SCREEN_HEIGHT, "Test");
    defer rl.CloseWindow();
    rl.SetTargetFPS(60);
    rl.DisableCursor();

    // Load program data
    var app = try App.init(&allocator, &rnd);
    defer app.deinit();

    // Run program
    while (!rl.WindowShouldClose()) {
        app.updateAndDraw();
    }
}
