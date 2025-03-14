#version 430 core

in vec2 fragTexCoord;
in vec4 fragColor;

struct Camera {
    double x, y;
    double w, h;
};

#define MANDLEBROT 0
#define JULIA_SET 1
#define BURNING_SHIP 2

layout(location = 1) uniform vec2 res;
uniform Camera cam;
uniform int iterations;
uniform vec2 zValue;
uniform int fractalType;

out vec4 finalColor;

dvec2 transformedPoint() {
    double x = gl_FragCoord.x;
    double y = gl_FragCoord.y;
    double scaled_x = x * cam.w / res.x;
    double scaled_y = (res.y - y) * cam.h / res.y;

    double cr = cam.x + (scaled_x - cam.w / 2.0);
    double ci = cam.y + (scaled_y - cam.h / 2.0);
    return dvec2(cr, ci);
}

// https://darkeclipz.github.io/fractals/paper/Fractals%20&%20Rendering%20Techniques.html
vec3 pallete(float t, vec3 a, vec3 b, vec3 c, vec3 d) {
    return a + b * cos(6.28318 * (c*t + d));
}

#define R 4.0

float iterateMandlebrot(dvec2 p) {
    dvec2 c = p;
    dvec2 z = zValue;

    float i;
    for(i = 0.0; i < iterations; i++) {
        double real = z.x*z.x - z.y*z.y;
        double imag = 2 * z.x*z.y;
        z = dvec2(real, imag) + c;
        if(dot(z, z) > R * R) break;
    }

    return i;
    // smoothing
    //return i - log(log(dot(z, z)) / log(R)) / log(2.0);
}

float iterateJulia(dvec2 p) {
    dvec2 c = zValue;
    dvec2 z = p;

    float i;
    for(i = 0.0; i < iterations; i++) {
        double real = z.x*z.x - z.y*z.y;
        double imag = 2 * z.x*z.y;
        z = dvec2(real, imag) + c;
        if(dot(z, z) > R * R) break;
    }

    return i;
}

void main() {

    dvec2 point = transformedPoint();
    float value;
    if (fractalType == MANDLEBROT) {
        value = iterateMandlebrot(point) / float(iterations);   
    } else {
        value = iterateJulia(point) / iterations;
    }

    vec3 col = pallete(fract(value + 0.5), vec3(0.5), vec3(0.5), 
                   vec3(1), vec3(0.0, 0.1, 0.2));

    finalColor = vec4(value >= 0.99 ? vec3(0) : col, 1.0);
}
