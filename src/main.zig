// raylib-zig (c) Nikolas Wipper 2023

const rl = @import("raylib");
const std = @import("std");
const znoise = @import("znoise.zig");
const worldgen = @import("terrain_gen.zig");

const DEBUGFLAG: u8 = 1;
const TILESIZE: f32 = 64;
const VIEWPORTWIDTH: usize = 21;
const VIEWPORTHEIGHT: usize = 15;
// Make sure to change if your computer is slow
const MAPWIDTH: usize = 101;
const MAPHEIGHT: usize = 101;
//--------------------------------------------------------------------------------------

const MOVETIMEDELAY: f64 = 0.01;
var LASTMOVEUPDATETIME: f64 = 0.0;

const Viewport = struct {
    width: usize,
    height: usize,
    x: usize,
    y: usize,
};

const Character = struct {};

const GameWorld = struct {
    width: usize,
    height: usize,
    tiles: [][]worldgen.Tile,
    charWorldPos: rl.Vector2,
    charRenderPos: rl.Vector2,
    viewPort: Viewport,

    fn init(allocator: std.mem.Allocator, viewPort: Viewport, width: usize, height: usize) !GameWorld {
        return GameWorld{
            .width = width,
            .height = height,
            .tiles = try worldgen.tileEcoGen(allocator, height, width),
            .charWorldPos = rl.Vector2.init(0, 0),
            .charRenderPos = rl.Vector2.init(TILESIZE / 2, TILESIZE / 2),
            .viewPort = viewPort,
        };
    }

    fn deinit(self: GameWorld, allocator: std.mem.Allocator) void {
        for (self.tiles) |row| {
            allocator.free(row);
        }
        allocator.free(self.tiles);
    }

    fn render(self: GameWorld, tileSize: f32) void {
        const viewStartX = self.viewPort.x;
        const viewStartY = self.viewPort.y;
        const viewEndX = @min(self.viewPort.x + self.viewPort.width, self.width);
        const viewEndY = @min(self.viewPort.y + self.viewPort.height, self.height);

        for (self.tiles[viewStartY..viewEndY], viewStartY..) |row, y| {
            for (row[viewStartX..viewEndX], viewStartX..) |tile, x| {
                const screenX = @as(f32, @floatFromInt(x - viewStartX)) * tileSize;
                const screenY = @as(f32, @floatFromInt(y - viewStartY)) * tileSize;

                const rect = rl.Rectangle{
                    .x = screenX,
                    .y = screenY,
                    .width = tileSize,
                    .height = tileSize,
                };
                rl.drawRectangleRec(rect, tile.color);
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
    const x = TILESIZE * (VIEWPORTWIDTH + 1);
    const y = 20;
    const fontSize = 11;
    const color = rl.Color.black;
    const spacing = fontSize + 10;

    for (texts, 0..) |text, i| {
        const padding: i32 = @intCast(i * spacing);
        rl.drawText(text, x, y + padding, fontSize, color);
    }
}

fn renderDebugInfo(gameWorld: GameWorld) void {
    const debugCharacterRenderLoc = convertToString(
        "Character render position: ({d:.},{d:.})",
        .{ gameWorld.charRenderPos.x, gameWorld.charRenderPos.y },
    );
    defer std.heap.page_allocator.free(debugCharacterRenderLoc);

    const debugCharacterGameworldLoc = convertToString(
        "Character game world position: ({d:.},{d:.})",
        .{ gameWorld.charWorldPos.x, gameWorld.charWorldPos.y },
    );
    defer std.heap.page_allocator.free(debugCharacterGameworldLoc);

    const debugViewPortStart = convertToString(
        "Viewport coords: ({d:.},{d:.})",
        .{ gameWorld.viewPort.x, gameWorld.viewPort.y },
    );
    defer std.heap.page_allocator.free(debugViewPortStart);

    const debugPrintouts = [_][:0]const u8{
        debugCharacterGameworldLoc,
        debugCharacterRenderLoc,
        debugViewPortStart,
    };

    renderDebugPanel(&debugPrintouts);
}

fn viewStateUpdate(gameWorld: *GameWorld, moveDir: rl.Vector2) void {
    // TODO there is a bug where if you go the right edge of the screen and then back the viewport will not change
    const midOfViewPortWidth = ((gameWorld.viewPort.width + 1) / 2);
    const midOfViewPortHeight = ((gameWorld.viewPort.height + 1) / 2);
    const lowerBoundViewPortHeight = @as(f32, @floatFromInt(midOfViewPortHeight - 1));
    const upperBoundViewPortHeight = @as(f32, @floatFromInt(gameWorld.height - midOfViewPortHeight));
    const lowerBoundViewPortWidth = @as(f32, @floatFromInt(midOfViewPortWidth - 1));
    const upperBoundViewPortWidth = @as(f32, @floatFromInt(gameWorld.width - midOfViewPortWidth));
    // std.debug.print(
    //     "upperBoundViewPort: {d}\nlowerBoundViewPort: {d}\nmidOfViewPortWidth: {d}\n\n",
    //     .{ upperBoundViewPort, lowerBoundViewPort, midOfViewPortWidth },
    // );

    std.debug.print(
        "Before update viewPort: ({},{})\nBefore update characterPosition: ({d},{d})\n\n",
        .{ gameWorld.viewPort.x, gameWorld.viewPort.y, gameWorld.charWorldPos.x, gameWorld.charWorldPos.y },
    );

    if (moveDir.x == 1) {
        if (gameWorld.charWorldPos.x != @as(f32, @floatFromInt(gameWorld.width - 1))) {
            if (gameWorld.charWorldPos.x >= lowerBoundViewPortWidth and
                gameWorld.charWorldPos.x < upperBoundViewPortWidth)
            {
                gameWorld.viewPort.x += 1;
            } else {
                gameWorld.charRenderPos.x += TILESIZE;
            }
            gameWorld.charWorldPos.x += 1;
        }
    } else if (moveDir.y == 1) {
        if (gameWorld.charWorldPos.y != @as(f32, @floatFromInt(gameWorld.height - 1))) {
            if (gameWorld.charWorldPos.y >= lowerBoundViewPortHeight and
                gameWorld.charWorldPos.y < upperBoundViewPortHeight)
            {
                gameWorld.viewPort.y += 1;
            } else {
                gameWorld.charRenderPos.y += TILESIZE;
            }
            gameWorld.charWorldPos.y += 1;
        }
    } else if (moveDir.x == -1) {
        if (gameWorld.charWorldPos.x != 0) {
            if (gameWorld.charWorldPos.x > lowerBoundViewPortWidth and
                gameWorld.charWorldPos.x <= upperBoundViewPortWidth)
            {
                gameWorld.viewPort.x -= 1;
            } else {
                gameWorld.charRenderPos.x -= TILESIZE;
            }
            gameWorld.charWorldPos.x -= 1;
        }
    } else if (moveDir.y == -1) {
        if (gameWorld.charWorldPos.y != 0) {
            if (gameWorld.charWorldPos.y > lowerBoundViewPortHeight and
                gameWorld.charWorldPos.y <= upperBoundViewPortHeight)
            {
                gameWorld.viewPort.y -= 1;
            } else {
                gameWorld.charRenderPos.y -= TILESIZE;
            }
            gameWorld.charWorldPos.y -= 1;
        }
    }

    std.debug.print(
        "After update viewPort: ({},{})\nAfter update characterPosition: ({d},{d})\n\n",
        .{ gameWorld.viewPort.x, gameWorld.viewPort.y, gameWorld.charWorldPos.x, gameWorld.charWorldPos.y },
    );
}

pub fn main() anyerror!void {
    // Initialization
    //--------------------------------------------------------------------------------------
    const screenWidth = TILESIZE * VIEWPORTWIDTH;
    const screenHeight = TILESIZE * VIEWPORTHEIGHT;

    const windowPosX = -3350;
    //const windowPosX = 500;
    const windowPosY = -200;

    rl.initWindow(screenWidth, screenHeight, "Game");
    defer rl.closeWindow(); // Close window and OpenGL context

    rl.setWindowPosition(windowPosX, windowPosY);
    rl.setTargetFPS(60); // Set our game to run at 60 frames-per-second

    // Game State
    //--------------------------------------------------------------------------------------
    var viewPort = Viewport{
        .width = VIEWPORTWIDTH,
        .height = VIEWPORTHEIGHT,
        .x = 0,
        .y = 0,
    };
    var allocator = std.heap.page_allocator;
    var gameWorld = try GameWorld.init(allocator, viewPort, MAPWIDTH, MAPHEIGHT);
    defer gameWorld.deinit(allocator);

    const grassTexture = rl.loadTexture("resources/terrain/grass_2.png");
    _ = grassTexture;

    // Main game loop
    //--------------------------------------------------------------------------------------
    while (!rl.windowShouldClose()) { // Detect window close button or ESC key
        // State update
        const currentTime = @as(f64, @floatFromInt(std.time.milliTimestamp()));

        if ((currentTime - LASTMOVEUPDATETIME) / 1000 > MOVETIMEDELAY) {
            if (rl.isKeyPressed(rl.KeyboardKey.key_right) or
                rl.isKeyPressed(rl.KeyboardKey.key_up) or
                rl.isKeyPressed(rl.KeyboardKey.key_left) or
                rl.isKeyPressed(rl.KeyboardKey.key_down) or
                rl.isKeyDown(rl.KeyboardKey.key_right) or
                rl.isKeyDown(rl.KeyboardKey.key_up) or
                rl.isKeyDown(rl.KeyboardKey.key_left) or
                rl.isKeyDown(rl.KeyboardKey.key_down))
            {
                var moveDir = rl.Vector2.init(0, 0);

                if (rl.isKeyPressed(rl.KeyboardKey.key_right) or rl.isKeyDown(rl.KeyboardKey.key_right)) {
                    moveDir.x = 1;
                    moveDir.y = 0;
                } else if (rl.isKeyPressed(rl.KeyboardKey.key_up) or rl.isKeyDown(rl.KeyboardKey.key_up)) {
                    moveDir.x = 0;
                    moveDir.y = -1;
                } else if (rl.isKeyPressed(rl.KeyboardKey.key_left) or rl.isKeyDown(rl.KeyboardKey.key_left)) {
                    moveDir.x = -1;
                    moveDir.y = 0;
                } else if (rl.isKeyPressed(rl.KeyboardKey.key_down) or rl.isKeyDown(rl.KeyboardKey.key_down)) {
                    moveDir.x = 0;
                    moveDir.y = 1;
                }

                LASTMOVEUPDATETIME = currentTime;
                viewStateUpdate(&gameWorld, moveDir);
            }
        }

        // Render
        rl.beginDrawing();
        defer rl.endDrawing();

        rl.clearBackground(rl.Color.ray_white);

        gameWorld.render(TILESIZE);

        // rl.drawTexture(grassTexture, 0, 0, rl.Color.white);

        rl.drawCircleV(gameWorld.charRenderPos, TILESIZE / 3 + 1, rl.Color.red);

        //renderDebugInfo(gameWorld);
    }
}
