// raylib-zig (c) Nikolas Wipper 2023

const rl = @import("raylib");
const std = @import("std");

const DEBUGFLAG: u8 = 1;
const TILESIZE: i64 = 32;
const VIEWPORTLENGTH: i32 = 25;
const VIEWPORTWIDTH: i32 = 25;

const Character = struct { renderPosition: rl.Vector2, worldPosition: rl.Vector2 };

const TerrainType = enum { Grass, Forest };

const Tile = struct { terrain: TerrainType };

const GameWorld = struct {
    width: usize,
    height: usize,
    tiles: [][]Tile,
    charWorldPos: rl.Vector2,
    charRenderPos: rl.Vector2,

    fn init(allocator: std.mem.Allocator, width: usize, height: usize) !GameWorld {
        var tiles = try allocator.alloc([]Tile, height);
        for (tiles) |*row| {
            row.* = try allocator.alloc(Tile, width);
            for (row.*) |*tile| {
                tile.* = Tile{ .terrain = .Grass };
            }
        }

        return GameWorld{ .width = width, .height = height, .tiles = tiles, .charWorldPos = rl.Vector2.init(0, 0), .charRenderPos = rl.Vector2.init((((VIEWPORTLENGTH + 1) / 2) - 1) * TILESIZE + (TILESIZE / 2), (((VIEWPORTLENGTH + 1) / 2) - 1) * TILESIZE + (TILESIZE / 2)) };
    }

    fn deinit(self: GameWorld, allocator: std.mem.Allocator) void {
        for (self.tiles) |row| {
            allocator.free(row);
        }
        allocator.free(self.tiles);
    }

    fn render(self: GameWorld, tileSize: f32) void {
        for (self.tiles, 0..) |row, y| {
            for (row, 0..) |tile, x| {
                const color = switch (tile.terrain) {
                    .Grass => rl.Color.green,
                    .Forest => rl.Color.dark_green,
                };
                const rect = rl.Rectangle{
                    .x = @as(f32, @floatFromInt(x)) * tileSize,
                    .y = @as(f32, @floatFromInt(y)) * tileSize,
                    .width = tileSize,
                    .height = tileSize,
                };
                rl.drawRectangleRec(rect, color);
                rl.drawRectangleLinesEx(rect, 0.5, rl.Color.light_gray);
            }
        }
    }
};

fn convertToString(comptime message: []const u8, args: anytype) [:0]const u8 {
    var allocator = std.heap.page_allocator;
    return std.fmt.allocPrintZ(allocator, message, args) catch unreachable;
}

fn renderDebugPanel(texts: []const [:0]const u8) void {
    const posX = TILESIZE * (VIEWPORTLENGTH + 1);
    const posY = 20;
    const fontSize = 11;
    const color = rl.Color.black;
    const spacing = fontSize + 10;

    for (texts, 0..) |text, i| {
        const padding: i32 = @intCast(i * spacing);
        rl.drawText(text, posX, posY + padding, fontSize, color);
    }
}

fn characterUpdate(gameWorld: *GameWorld, moveDir: rl.Vector2) void {
    if (moveDir.x == 1) {
        gameWorld.charRenderPos.x += TILESIZE;
        gameWorld.charWorldPos.x += 1;
    } else if (moveDir.y == 1) {
        gameWorld.charRenderPos.y += TILESIZE;
        gameWorld.charWorldPos.y -= 1;
    } else if (moveDir.x == -1) {
        gameWorld.charRenderPos.x -= TILESIZE;
        gameWorld.charWorldPos.x -= 1;
    } else if (moveDir.y == -1) {
        gameWorld.charRenderPos.y -= TILESIZE;
        gameWorld.charWorldPos.y += 1;
    }
}

pub fn main() anyerror!void {
    // Initialization
    //--------------------------------------------------------------------------------------
    const screenWidth = 1052;
    const screenHeight = 800;

    // const windowPosX = -3000;
    const windowPosX = 500;
    const windowPosY = 0;

    rl.initWindow(screenWidth, screenHeight, "Game");
    defer rl.closeWindow(); // Close window and OpenGL context

    rl.setWindowPosition(windowPosX, windowPosY);
    rl.setTargetFPS(60); // Set our game to run at 60 frames-per-second

    // Game State
    //--------------------------------------------------------------------------------------
    var allocator = std.heap.page_allocator;
    var gameWorld = try GameWorld.init(allocator, 25, 25);
    defer gameWorld.deinit(allocator);

    var character = Character{ .renderPosition = rl.Vector2.init(16, 16), .worldPosition = rl.Vector2.init(0, 0) };
    _ = character;

    // Main game loop
    //--------------------------------------------------------------------------------------
    while (!rl.windowShouldClose()) { // Detect window close button or ESC key
        // State update

        if (rl.isKeyPressed(rl.KeyboardKey.key_right) or
            rl.isKeyPressed(rl.KeyboardKey.key_up) or
            rl.isKeyPressed(rl.KeyboardKey.key_left) or
            rl.isKeyPressed(rl.KeyboardKey.key_down))
        {
            var moveDir = rl.Vector2.init(0, 0);

            if (rl.isKeyPressed(rl.KeyboardKey.key_right)) {
                moveDir.x = 1;
                moveDir.y = 0;
            } else if (rl.isKeyPressed(rl.KeyboardKey.key_up)) {
                moveDir.x = 0;
                moveDir.y = -1;
            } else if (rl.isKeyPressed(rl.KeyboardKey.key_left)) {
                moveDir.x = -1;
                moveDir.y = 0;
            } else if (rl.isKeyPressed(rl.KeyboardKey.key_down)) {
                moveDir.x = 0;
                moveDir.y = 1;
            }
            characterUpdate(&gameWorld, moveDir);
        }

        // Render
        rl.beginDrawing();

        defer rl.endDrawing();

        rl.clearBackground(rl.Color.white);

        gameWorld.render(TILESIZE);

        rl.drawCircleV(gameWorld.charRenderPos, 12, rl.Color.red);

        const debugCharacterRenderLoc = convertToString("Character render position: ({d:.},{d:.})", .{ gameWorld.charRenderPos.x, gameWorld.charRenderPos.y });
        defer std.heap.page_allocator.free(debugCharacterRenderLoc);

        const debugCharacterGameworldLoc = convertToString("Character render position: ({d:.},{d:.})", .{ gameWorld.charWorldPos.x, gameWorld.charWorldPos.y });
        defer std.heap.page_allocator.free(debugCharacterGameworldLoc);

        const debugPrintouts = [_][:0]const u8{ debugCharacterGameworldLoc, debugCharacterRenderLoc };

        renderDebugPanel(&debugPrintouts);
    }
}
