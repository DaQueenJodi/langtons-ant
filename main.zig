const std = @import("std");
const c = @import("c.zig");

const WINDOW_WIDTH = CELL_SIZE*GRID_WIDTH;
const WINDOW_HEIGHT = CELL_SIZE*GRID_HEIGHT;

const CELL_SIZE = 4;
const GRID_WIDTH = 200;
const GRID_HEIGHT = 200;

const FAST_FORWARD_KEY = c.KEY_SPACE;
const FAST_FORWARD_MULTIPLIER = 2.5;
const DEFAULT_DELAY = 1;

const WRAPPING = true;

const ANT_COLOR = c.RED;
const WHITE_COLOR = c.WHITE;
const BLACK_COLOR = c.BLACK;

const Direction = enum {
    left,
    right,
    up,
    down,
    pub fn left(dir: Direction) Direction {
        return switch (dir) {
            .left => .down,
            .right => .up,
            .up => .left,
            .down => .right
        };
    }
    pub fn right(dir: Direction) Direction {
        return switch (dir) {
            .left => .up,
            .right => .down,
            .up => .right,
            .down => .left
        };
    }
};
test "directions" {
    const directions = [_]Direction{.left, .right, .up, .down};
    for (directions) |dir| {
        try std.testing.expectEqual(dir, dir.left().left().left().left());
        try std.testing.expectEqual(dir, dir.right().right().right().right());
    }
}

const Turn = enum {
    right,
    left,
    straight,
    uturn
};

const Tile = struct {
    color: c.Color,
    turn: Turn
};

const Config = struct {
    wrap: bool,
    ants:  []const ?Ant,
    tiles: []const Tile
};
const CONFIGURATION2 = Config{
    .wrap = true,
    .ants = &[_]?Ant{
        Ant{.x = 43, .y = 57, .direction = .right}
    },
    .tiles = &[_]Tile{
        .{.color = c.WHITE, .turn = .straight},
        .{.color = c.BLACK, .turn = .straight}
        //.{.color = c.GREEN, .turn = .straight},
        //.{.color = c.BROWN, .turn = .uturn}
    }
};
const CONFIGURATION0 = Config{
    .ants = &[_]?Ant{
        Ant{.x = 57, .y = 57, .direction = .up},
        Ant{.x = 57, .y = 43, .direction = .left},
        Ant{.x = 43, .y = 43, .direction = .down},
        Ant{.x = 43, .y = 57, .direction = .right},

    },
    .tiles = &[_]Tile{
        .{.color = c.WHITE, .turn = .right},
        .{.color = c.BLACK, .turn = .left},
        //.{.color = c.GREEN, .turn = .straight},
        //.{.color = c.BROWN, .turn = .uturn}
    }
};
const CONFIGURATION = Config{
    .wrap = true,
    .ants = &[_]?Ant{
        Ant{.x = 50, .y = 45, .direction = .down},
        Ant{.x = 55, .y = 50, .direction = .left},
        Ant{.x = 50, .y = 55, .direction = .up},
        Ant{.x = 45, .y = 50, .direction = .right},

        Ant{.x = 150, .y = 45, .direction = .down},
        Ant{.x = 155, .y = 50, .direction = .left},
        Ant{.x = 150, .y = 55, .direction = .up},
        Ant{.x = 145, .y = 50, .direction = .right},

        Ant{.x = 150, .y = 145, .direction = .down},
        Ant{.x = 155, .y = 150, .direction = .left},
        Ant{.x = 150, .y = 155, .direction = .up},
        Ant{.x = 145, .y = 150, .direction = .right},

        Ant{.x = 50, .y = 145, .direction = .down},
        Ant{.x = 55, .y = 150, .direction = .left},
        Ant{.x = 50, .y = 155, .direction = .up},
        Ant{.x = 45, .y = 150, .direction = .right},

    },
    .tiles = &[_]Tile{
        .{.color = c.WHITE,    .turn = .left},
        .{.color = c.RED,      .turn = .right},
        .{.color = c.ORANGE,   .turn = .left},
        .{.color = c.YELLOW,   .turn = .right},
        .{.color = c.GREEN,    .turn = .left},
        .{.color = c.BLUE,     .turn = .right}
    }
};


const Ant = struct {
    x: usize,
    y: usize,
    direction: Direction,
    dead: bool = false,
    pub fn forward(ant: Ant) struct { x: i32, y: i32 } {
        const x1: i32 = @intCast(ant.x);
        const y1: i32 = @intCast(ant.y);
        return switch (ant.direction) {
            .left  => .{.x = x1 - 1, .y = y1},
            .right => .{.x = x1 + 1, .y = y1},
            .up    => .{.x = x1,     .y = y1 - 1},
            .down  => .{.x = x1,     .y = y1 + 1},
        };
    }
};


const CellState = struct {
    n: usize,
    pub fn getColor(state: CellState) c.Color {
        return CONFIGURATION.tiles[state.n].color;
    }
    pub fn next(state: CellState) CellState {
        return .{ .n = (state.n + 1) % CONFIGURATION.tiles.len };
    }
};

fn next(grid: *[GRID_HEIGHT*GRID_WIDTH]CellState, ant: *Ant) bool {
    const cell = &grid[ant.y*GRID_HEIGHT+ant.x];
    const turn = CONFIGURATION.tiles[cell.n].turn;
    switch (turn) {
        .right => ant.direction = ant.direction.right(),
        .left => ant.direction = ant.direction.left(),
        .uturn => ant.direction = ant.direction.left().left(),
        .straight => {}
    }
    cell.* = cell.next();
    var new_loc = ant.forward();
    // dead or wrap
    if (new_loc.x < 0 or new_loc.y < 0 or new_loc.x >= GRID_WIDTH or new_loc.y >= GRID_HEIGHT) {
        if (!CONFIGURATION.wrap) return false;
        if (new_loc.x < 0) new_loc.x = GRID_WIDTH-1
        else if (new_loc.x >= GRID_WIDTH) new_loc.x = 0
        else if (new_loc.y < 0) new_loc.y = GRID_HEIGHT-1
        else if (new_loc.y >= GRID_HEIGHT) new_loc.y = 0;
    }

    ant.x = @intCast(new_loc.x);
    ant.y = @intCast(new_loc.y);

    return true;
}

fn isAnt(x: usize, y: usize, ants: [CONFIGURATION.ants.len]Ant) bool {
    for (ants) |ant| {
        if (x == ant.x and y == ant.y) return true;
    }
    return false;
}

pub fn main() !void {
    var paused = true;
    var fast_forward = false;
    var seed: u64 = undefined;
    try std.os.getrandom(std.mem.asBytes(&seed));
    var pcg = std.rand.Pcg.init(seed);
    const rand = pcg.random();
    var ants: [CONFIGURATION.ants.len]Ant = undefined;
    for (&ants, 0..) |*ant, i| {
        if (CONFIGURATION.ants[i]) |default| {
            ant.* = default;
        } else {
            ant.* = Ant{
                .x = rand.intRangeLessThan(usize, 0, GRID_WIDTH),
                .y = rand.intRangeLessThan(usize, 0, GRID_HEIGHT),
                // unfortunately rand.enumValue doesn't work if the enum has associated functions
                .direction = @enumFromInt(rand.intRangeLessThan(usize, 0, 4)),
            };
        }
    }
    var grid: [GRID_HEIGHT*GRID_WIDTH]CellState = undefined;
    for (&grid) |*cell| cell.* = .{.n = 0};

    c.SetTraceLogLevel(c.LOG_DEBUG | c.LOG_ERROR | c.LOG_WARNING);
    c.SetTargetFPS(120);
    c.InitWindow(WINDOW_WIDTH, WINDOW_HEIGHT, "welp");
    while (!c.WindowShouldClose()) {
        if (c.IsKeyPressed(FAST_FORWARD_KEY)) {
            fast_forward = !fast_forward;
            std.log.info("fast forwarding turned {s}!\n", .{if (fast_forward) "on" else "off"});
        }
        c.BeginDrawing();
            c.ClearBackground(c.BLACK);
            for (0..GRID_HEIGHT) |y| {
                for (0..GRID_WIDTH) |x| {
                    const cell = grid[y*GRID_HEIGHT+x];
                    const color = if (isAnt(x, y, ants)) ANT_COLOR else cell.getColor();
                    c.DrawRectangle(
                        @intCast(y*CELL_SIZE), @intCast(x*CELL_SIZE),
                        CELL_SIZE, CELL_SIZE, color);
                }
            }
        c.EndDrawing();
        if (c.IsKeyPressed(c.KEY_ENTER)) paused = !paused;
        if (!paused) {
            for (&ants, 0..) |*ant, i| {
                if (ant.dead) continue;
                if (!next(&grid, ant)) {
                    std.log.info("ant number {} just died :(", .{i});
                    ant.dead = true;
                }
            }
        }
        const sleepy_time: u64 = DEFAULT_DELAY;
        _ = sleepy_time;//if (fast_forward) DEFAULT_DELAY/FAST_FORWARD_MULTIPLIER else DEFAULT_DELAY;
        //std.time.sleep(sleepy_time);
    }
    c.CloseWindow();
}
