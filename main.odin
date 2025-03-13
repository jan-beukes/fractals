package fractals

import "core:fmt"
import "core:math"
import "core:math/cmplx"
import "core:thread"
import rl "vendor:raylib"

WINDOW_WIDTH :: 1280
WINDOW_HEIGHT :: 720

RESX :: WINDOW_WIDTH
RESY :: WINDOW_HEIGHT

THREAD_COUNT :: 10

ZOOM_STEP :: 0.7
DEFAULT_CAM_X :: -0.5
DEFAULT_CAM_Y :: 0.0
DEFAULT_CAM_W :: 3.14
DEFAULT_CAM_H :: DEFAULT_CAM_W * WINDOW_HEIGHT / WINDOW_WIDTH

Camera :: struct {
    x, y: f64,
    w, h: f64,
}

Fractal :: enum {
    Mandlebrot,
    Julia_Set,
    Burning_Ship,
}

Thread_Context :: struct {
    id:          i32,
    fractal:     Fractal,
    cam:         ^Camera,
    surface:     ^rl.Image,

    // state
    start_draw:  bool,
    is_done:     bool,
    should_quit: bool,
}


threads: [THREAD_COUNT]Thread_Context

camera_scale :: proc(cam: Camera, x, y: f32) -> (f64, f64) {
    scaled_x := f64(x) * cam.w / f64(RESX)
    scaled_y := f64(y) * cam.h / f64(RESY) // we want 0,0 in the center for easier positioning
    return scaled_x, scaled_y
}

screen_to_point :: proc(cam: Camera, x, y: i32) -> (f64, f64) {
    scaled_x, scaled_y := camera_scale(cam, f32(x), f32(y))

    cr := cam.x + (scaled_x - cam.w / 2.0)
    ci := cam.y + (scaled_y - cam.h / 2.0)
    return cr, ci
}


MAX_VALUE :: 500
draw_mandlebrot :: proc(surface: ^rl.Image, camera: Camera, start_x, start_y, width, height: i32) {

    for y in start_y ..< start_y + height {
        for x in start_x ..< start_x + width {

            cr, ci := screen_to_point(camera, x, y)

            c: complex128 = complex(cr, ci)
            z: complex128

            value := MAX_VALUE
            for i in 0 ..< MAX_VALUE {
                z = z * z + c
                if abs(z) > 2 {
                    value = i
                    break
                }
            }
            gray := u8(255 * value / MAX_VALUE)
            rl.ImageDrawPixel(surface, i32(x), i32(y), {gray, gray, gray, 255})
        }
    }

}

render_proc :: proc(ctx: ^Thread_Context) {
    h: i32 = RESY / THREAD_COUNT
    y := ctx.id * h
    // last thread will have more/less pixels to work on
    if ctx.id == THREAD_COUNT - 1 {
        h = RESY - y
    }

    for !ctx.should_quit {

        for !ctx.start_draw {}
        ctx.is_done = false
        ctx.start_draw = false

        switch ctx.fractal {
        case .Mandlebrot:
            {
                draw_mandlebrot(ctx.surface, ctx.cam^, 0, y, RESX, h)
            }
        case .Julia_Set:
        case .Burning_Ship:
        }
        ctx.is_done = true
    }
}

// get threads to start rendering and wait for all to finnish
render_and_wait :: proc() {
    for i in 0 ..< THREAD_COUNT {
        threads[i].start_draw = true
    }

    wait_idx := 0
    for wait_idx < THREAD_COUNT {
        if threads[wait_idx].is_done {
            wait_idx += 1
        }
    }
}

spawn_threads :: proc(surface: ^rl.Image, cam: ^Camera) {
    for i in 0 ..< THREAD_COUNT {
        ctx := Thread_Context {
            id      = i32(i),
            fractal = .Mandlebrot,
            cam     = cam,
            surface = surface,
        }
        threads[i] = ctx
        thread.run_with_poly_data(&threads[i], render_proc, context)
    }
}

main :: proc() {

    rl.InitWindow(WINDOW_WIDTH, WINDOW_HEIGHT, "Fractals!")
    rl.SetTargetFPS(60)
    defer rl.CloseWindow()

    camera := Camera {
        x = DEFAULT_CAM_X,
        y = DEFAULT_CAM_Y,
        w = DEFAULT_CAM_W,
        h = DEFAULT_CAM_H,
    }

    surface := rl.GenImageColor(RESX, RESY, rl.WHITE)
    target := rl.LoadTextureFromImage(surface)

    spawn_threads(&surface, &camera)

    for !rl.WindowShouldClose() {

        if rl.IsMouseButtonDown(.LEFT) {
            delta := rl.GetMouseDelta()
            dx, dy := camera_scale(camera, delta.x, delta.y)
            camera.x -= dx
            camera.y -= dy
        }
        scroll := rl.GetMouseWheelMove()
        if scroll > 0.0 {
            camera.w *= ZOOM_STEP
            camera.h = camera.w * f64(WINDOW_HEIGHT) / f64(WINDOW_WIDTH)
        } else if scroll < 0.0 {
            camera.w /= ZOOM_STEP
            camera.h = camera.w * f64(WINDOW_HEIGHT) / f64(WINDOW_WIDTH)
        }

        render_and_wait()
        rl.UpdateTexture(target, surface.data)

        rl.BeginDrawing()
        src := rl.Rectangle{0, 0, f32(target.width), f32(target.height)}
        dst := rl.Rectangle{0, 0, WINDOW_WIDTH, WINDOW_HEIGHT}
        rl.DrawTexturePro(target, src, dst, rl.Vector2(0), 0, rl.WHITE)

        rl.DrawFPS(10, 10)
        rl.EndDrawing()

    }
}
