const znoise = @import("znoise.zig");
const std = @import("std");
const rl = @import("raylib");

var SUM: f64 = 0;

pub const BiomeType = enum {
    Forest,
    Desert,
    Grassland,
    Tundra,
};

pub const TerrainType = enum {
    TallGrass,
    ShortGrass,
    ThickForest,
    ThinForest,
    SandyRock,
    Sand,
    Tyga,
    Snow,
};

pub const Tile = struct {
    biome: BiomeType,
    terrain: TerrainType,
    color: rl.Color,
};

fn getTileColor(terrain: TerrainType) rl.Color {
    return switch (terrain) {
        .TallGrass => rl.Color{
            .r = 19,
            .g = 109,
            .b = 21,
            .a = 255,
        },
        .ShortGrass => rl.Color{
            .r = 65,
            .g = 152,
            .b = 10,
            .a = 255,
        },
        .ThickForest => rl.Color{
            .r = 25,
            .g = 39,
            .b = 13,
            .a = 255,
        },
        .ThinForest => rl.Color{
            .r = 129,
            .g = 140,
            .b = 60,
            .a = 255,
        },
        .SandyRock => rl.Color{
            .r = 159,
            .g = 86,
            .b = 26,
            .a = 255,
        },
        .Sand => rl.Color{
            .r = 249,
            .g = 161,
            .b = 89,
            .a = 255,
        },
        .Tyga => rl.Color{
            .r = 120,
            .g = 173,
            .b = 206,
            .a = 255,
        },
        .Snow => rl.Color{
            .r = 216,
            .g = 222,
            .b = 223,
            .a = 255,
        },
    };
}

fn generateBiome(x: usize, y: usize) BiomeType {
    const noiseValue = znoise.noise(f32, .{
        .x = @as(f32, @floatFromInt(x)) * 0.02,
        .y = @as(f32, @floatFromInt(y)) * 0.02,
    });

    if (noiseValue > 0.75) {
        SUM += 1;
        std.debug.print("Noisevalue: {d:.}\nRunning Total: {d}\n\n", .{
            noiseValue,
            SUM,
        });
    }

    if (noiseValue <= 0.25) {
        return BiomeType.Grassland;
    } else if (noiseValue <= 0.5) {
        return BiomeType.Forest;
    } else if (noiseValue <= 0.75) {
        return BiomeType.Desert;
    } else {
        std.debug.print("tundra biome tile assigned", .{});
        return BiomeType.Tundra;
    }
}

fn generateTerrain(biome: BiomeType, x: usize, y: usize) TerrainType {
    const noiseValue = znoise.noise(f32, .{
        .x = @as(f32, @floatFromInt(x)) * 0.08,
        .y = @as(f32, @floatFromInt(y)) * 0.08,
    });

    return switch (biome) {
        .Grassland => if (noiseValue < 0.5) TerrainType.ShortGrass else TerrainType.TallGrass,
        .Forest => if (noiseValue < 0.5) TerrainType.ThinForest else TerrainType.ThickForest,
        .Desert => if (noiseValue < 0.5) TerrainType.Sand else TerrainType.SandyRock,
        .Tundra => if (noiseValue < 0.5) TerrainType.Tyga else TerrainType.Snow,
    };
}

pub fn tileEcoGen(allocator: std.mem.Allocator, height: usize, width: usize) ![][]Tile {
    var tiles = try allocator.alloc([]Tile, height);
    for (tiles, 0..) |*row, y| {
        row.* = try allocator.alloc(Tile, width);
        for (row.*, 0..) |*tile, x| {
            const biome = generateBiome(x, y);
            const terrain = generateTerrain(biome, x, y);
            const color = getTileColor(terrain);
            tile.* = Tile{ .biome = biome, .terrain = terrain, .color = color };
        }
    }
    return tiles;
}
