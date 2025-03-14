package fractals

import "core:fmt"
import "core:math"
import "core:math/cmplx"
import "core:thread"

import gl "vendor:OpenGL"
import rl "vendor:raylib"
import "vendor:raylib/rlgl"

// raylib does not have the option to set double uniforms by default
// so we need to manually call glUniform
foreign _ {
    glfwGetProcAddress :: proc(name: cstring) -> rawptr ---
}
gl_set_proc_address :: proc(p: rawptr, name: cstring) {
    (^rawptr)(p)^ = glfwGetProcAddress(name)
}

WINDOW_WIDTH :: 1600
WINDOW_HEIGHT :: 900

RESX :: WINDOW_WIDTH
RESY :: WINDOW_HEIGHT

ZOOM_FACTOR :: 0.8
ITER_STEP :: 20
MAX_ITER :: 2000

DEFAULT_CAM_X :: -0.5
DEFAULT_CAM_Y :: 0.0
DEFAULT_CAM_W :: 3.14
DEFAULT_CAM_H :: DEFAULT_CAM_W * WINDOW_HEIGHT / WINDOW_WIDTH

Camera :: struct {
    x, y: f64,
    w, h: f64,
}

Fractal :: enum i32 {
    Mandlebrot = 0,
    Julia_Set,
    Count,
}

camera_scale :: proc(cam: Camera, x, y: f32) -> (f64, f64) {
    scaled_x := f64(x) * cam.w / f64(WINDOW_WIDTH)
    scaled_y := f64(y) * cam.h / f64(WINDOW_HEIGHT) // we want 0,0 in the center for easier positioning
    return scaled_x, scaled_y
}

screen_to_point :: proc(cam: Camera, x, y: f32) -> (f64, f64) {
    scaled_x, scaled_y := camera_scale(cam, x, y)

    cr := cam.x + (scaled_x - cam.w / 2.0)
    ci := cam.y + (scaled_y - cam.h / 2.0)
    return cr, ci
}

zoom :: proc(cam: ^Camera, step: f64, dir: i32) {
    if dir == 0 do return

    mouse_pos := rl.GetMousePosition()
    mouse_x, mouse_y := screen_to_point(cam^, mouse_pos.x, mouse_pos.y)
    if dir > 0 {
        cam.w *= step
    } else {
        cam.w /= step
    }
    cam.h = cam.w * f64(WINDOW_HEIGHT) / f64(WINDOW_WIDTH)
    new_mouse_x, new_mouse_y := screen_to_point(cam^, mouse_pos.x, mouse_pos.y)
    cam.x -= (new_mouse_x - mouse_x)
    cam.y -= (new_mouse_y - mouse_y)
}

main :: proc() {

    rl.SetConfigFlags({.MSAA_4X_HINT})
    rl.InitWindow(WINDOW_WIDTH, WINDOW_HEIGHT, "Fractals!")
    defer rl.CloseWindow()
    rl.SetTargetFPS(60)

    camera := Camera {
        x = DEFAULT_CAM_X,
        y = DEFAULT_CAM_Y,
        w = DEFAULT_CAM_W,
        h = DEFAULT_CAM_H,
    }
    fractal: Fractal = .Mandlebrot

    gl.load_up_to(4, 3, gl_set_proc_address)
    shader := rl.LoadShader(nil, "shaders/fractals.frag")

    // Shader Locs
    res := rl.Vector2{RESX, RESY}
    rl.SetShaderValue(shader, 1, &res, .VEC2)

    cam_loc_x := rl.GetShaderLocation(shader, "cam.x")
    cam_loc_y := rl.GetShaderLocation(shader, "cam.y")
    cam_loc_w := rl.GetShaderLocation(shader, "cam.w")
    cam_loc_h := rl.GetShaderLocation(shader, "cam.h")

    iter_loc := rl.GetShaderLocation(shader, "iterations")
    type_loc := rl.GetShaderLocation(shader, "fractalType")
    z_value_loc := rl.GetShaderLocation(shader, "zValue")

    z_value := rl.Vector2{0, 0}
    iterations: i32 = 400.0

    for !rl.WindowShouldClose() {
        dt := rl.GetFrameTime()

        if rl.IsMouseButtonDown(.LEFT) {
            delta := rl.GetMouseDelta()
            dx, dy := camera_scale(camera, delta.x, delta.y)
            camera.x -= dx
            camera.y -= dy
        }
        if rl.IsKeyPressed(.H) {
            if rl.IsCursorHidden() {
                rl.ShowCursor()
            } else {
                rl.HideCursor()
            }
        }
        if rl.IsKeyPressed(.EQUAL) {
            iterations += ITER_STEP
            iterations = min(iterations, MAX_ITER)
        } else if rl.IsKeyPressed(.MINUS) {
            iterations -= ITER_STEP
            iterations = max(iterations, 0)
        }

        scroll := rl.GetMouseWheelMove()
        if scroll > 0.0 {
            zoom(&camera, ZOOM_FACTOR, 1)
        } else if rl.IsKeyDown(.SPACE) {
            zoom(&camera, (1.0 - f64(dt) * 0.5), 1)
        } else if scroll < 0.0 {
            zoom(&camera, ZOOM_FACTOR, -1)
        } else if rl.IsKeyDown(.LEFT_CONTROL) {
            zoom(&camera, (1.0 - f64(dt) * 0.6), -1)
        }

        rl.SetShaderValue(shader, z_value_loc, &z_value, .VEC2)
        rl.SetShaderValue(shader, iter_loc, &iterations, .INT)

        rlgl.EnableShader(shader.id)
        gl.Uniform1d(cam_loc_x, camera.x)
        gl.Uniform1d(cam_loc_y, camera.y)
        gl.Uniform1d(cam_loc_w, camera.w)
        gl.Uniform1d(cam_loc_h, camera.h)


        rl.BeginDrawing()
        rl.ClearBackground(rl.BLACK)

        rl.BeginShaderMode(shader)
        rl.DrawRectangle(0, 0, WINDOW_WIDTH, WINDOW_HEIGHT, rl.WHITE)
        rl.EndShaderMode()


        // UI
        // Sliders
        bar_h: f32 = WINDOW_HEIGHT * 0.04
        bar_w: f32 = WINDOW_WIDTH * 0.15
        padding: f32 = bar_h * 0.1
        x := WINDOW_WIDTH - padding - bar_w
        y := WINDOW_HEIGHT - 2 * bar_h - 4 * padding
        rect := rl.Rectangle{x, y, bar_w, bar_h}
        ret := rl.GuiSlider(rect, "real: ", nil, &z_value.x, -2.0, 2.0) != 0
        rect.y += bar_h + padding
        ret = rl.GuiSlider(rect, "imag: ", nil, &z_value.y, -2.0, 2.0) != 0

        size: f32 = WINDOW_WIDTH * 0.05
        rect = rl.Rectangle {
            x      = WINDOW_WIDTH - padding - size,
            y      = padding,
            width  = size,
            height = size,
        }

        if rl.GuiButton(rect, "Toggle Set") {
            fractal = Fractal((i32(fractal) + 1) % i32(Fractal.Count))
            rl.SetShaderValue(shader, type_loc, &fractal, .INT)
            z_value = rl.Vector2(0)
        }

        // Text
        rl.DrawFPS(10, 10)
        rl.DrawText(rl.TextFormat("Iterations: %d", iterations), 10, 35, 20, rl.DARKGREEN)
        rl.EndDrawing()
    }
}
