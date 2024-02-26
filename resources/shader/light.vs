#version 100

attribute vec4 vertexTangent;
attribute vec3 vertexPosition;
attribute vec2 vertexTexCoord;
attribute vec3 vertexNormal;
attribute vec4 vertexColor;

uniform mat4 matNormal;
uniform mat4 matModel;
uniform mat4 mvp;

uniform vec3 viewLightPos;

varying vec3 fragPosition;
varying vec2 fragTexCoord;
varying vec3 fragNormal;
varying vec4 fragColor;

varying vec3 fragTanPos;
varying vec3 fragViewLightPos;
varying vec3 fragTanViewLightPos;

mat3 transpose(mat3 m)
{
    return mat3(m[0][0], m[1][0], m[2][0],
                m[0][1], m[1][1], m[2][1],
                m[0][2], m[1][2], m[2][2]);
}

void main()
{
    fragNormal = normalize(vec3(matNormal * vec4(vertexNormal, 0.0)));
    fragPosition = vec3(matModel * vec4(vertexPosition, 1.0));
    fragTexCoord = vertexTexCoord;
    fragColor = vertexColor;

    vec3 T = normalize(vec3(matModel * vec4(vertexTangent.xyz, 0.0)));
    vec3 B = cross(fragNormal, T) * vertexTangent.w;
    mat3 invTBN = transpose(mat3(T, B, fragNormal));

    fragViewLightPos = viewLightPos;
    fragTanPos = invTBN * fragPosition;
    fragTanViewLightPos = invTBN * viewLightPos;

    gl_Position = mvp * vec4(vertexPosition, 1.0);
}