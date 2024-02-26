#version 100

precision mediump float;

const float maxLightDist = 10.0;

varying vec3 fragPosition;
varying vec2 fragTexCoord;
varying vec3 fragNormal;
varying vec4 fragColor;

varying vec3 fragTanPos;
varying vec3 fragViewLightPos;
varying vec3 fragTanViewLightPos;

uniform sampler2D texture0;     // diffuse
uniform sampler2D texture1;     // specular
uniform sampler2D texture2;     // normal
uniform vec4 colDiffuse;

void main()
{
    // Calculate distance attenuation
    float attenuation = 1.0 - min(distance(fragViewLightPos, fragPosition) / maxLightDist, 1.0);
    if (attenuation == 0.0) discard;  // Discard fragments with no attenuation (no light contribution)

    // Obtain normal vector from normal map in the range [-1, 1]
    vec3 normal = normalize(texture2D(texture2, fragTexCoord).rgb * 2.0 - 1.0);

    // Diffuse reflection calculation
    vec3 viewLightDir = normalize(fragTanViewLightPos - fragTanPos);
    float diff = max(dot(viewLightDir, normal), 0.0);
    vec3 diffuse = diff * texture2D(texture0, fragTexCoord).rgb;

    // Specular reflection calculation
    vec3 reflectDir = reflect(-viewLightDir, normal);
    vec3 specular = pow(diff, 32.0) * texture2D(texture1, fragTexCoord).rgb; 

    // Final color calculation, taking into account both diffuse and specular reflections with attenuation
    gl_FragColor = vec4((diffuse + specular) * attenuation, 1.0);
}
