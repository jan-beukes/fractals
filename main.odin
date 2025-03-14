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

WINDOW_WIDTH :: 1280
WINDOW_HEIGHT :: 720

RESX :: WINDOW_WIDTH
RESY :: WINDOW_HEIGHT

THREAD_COUNT :: 12

ZOOM_STEP :: 0.9
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

camera_scale :: proc(cam: Camera, x, y: f32) -> (f64, f64) {
    scaled_x := f64(x) * cam.w / f64(RESX)
    scaled_y := f64(y) * cam.h / f64(RESY) // we want 0,0 in the center for easier positioning
    return scaled_x, scaled_y
}

screen_to_point :: proc(cam: Camera, x, y: f32) -> (f64, f64) {
    scaled_x, scaled_y := camera_scale(cam, x, y)

    cr := cam.x + (scaled_x - cam.w / 2.0)
    ci := cam.y + (scaled_y - cam.h / 2.0)
    return cr, ci
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

    gl.load_up_to(4, 3, gl_set_proc_address)
    shader := rl.LoadShader(nil, "shaders/mandlebrot.frag")

    // Shader Locs
    res := rl.Vector2{WINDOW_WIDTH, WINDOW_HEIGHT}
    rl.SetShaderValue(shader, 1, &res, .VEC2)

    cam_loc_x := rl.GetShaderLocation(shader, "cam.x")
    cam_loc_y := rl.GetShaderLocation(shader, "cam.y")
    cam_loc_w := rl.GetShaderLocation(shader, "cam.w")
    cam_loc_h := rl.GetShaderLocation(shader, "cam.h")

    itter_loc := rl.GetShaderLocation(shader, "itterations")
    z_value_loc := rl.GetShaderLocation(shader, "zValue")

    z_value := rl.Vector2{0, 0}
    itterations: i32 = 500
    rl.SetShaderValue(shader, z_value_loc, &z_value, .VEC2)
    rl.SetShaderValue(shader, itter_loc, &itterations, .INT)

    for !rl.WindowShouldClose() {

        if rl.IsMouseButtonDown(.LEFT) {
            delta := rl.GetMouseDelta()
            dx, dy := camera_scale(camera, delta.x, delta.y)
            camera.x -= dx
            camera.y -= dy
        }
        scroll := rl.GetMouseWheelMove()
        mouse_pos := rl.GetMousePosition()
        if scroll > 0.0 || rl.IsKeyDown(.EQUAL) {
            mouse_x, mouse_y := screen_to_point(camera, mouse_pos.x, mouse_pos.y)
            camera.w *= ZOOM_STEP
            camera.h = camera.w * f64(WINDOW_HEIGHT) / f64(WINDOW_WIDTH)
            new_mouse_x, new_mouse_y := screen_to_point(camera, mouse_pos.x, mouse_pos.y)
            camera.x -= (new_mouse_x - mouse_x)
            camera.y -= (new_mouse_y - mouse_y)
        } else if scroll < 0.0 || rl.IsKeyDown(.MINUS) {
            mouse_x, mouse_y := screen_to_point(camera, mouse_pos.x, mouse_pos.y)
            camera.w /= ZOOM_STEP
            camera.h = camera.w * f64(WINDOW_HEIGHT) / f64(WINDOW_WIDTH)
            new_mouse_x, new_mouse_y := screen_to_point(camera, mouse_pos.x, mouse_pos.y)
            camera.x -= (new_mouse_x - mouse_x)
            camera.y -= (new_mouse_y - mouse_y)
        }

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

        rl.DrawFPS(10, 10)
        rl.EndDrawing()
    }
}
