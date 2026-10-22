shader_type spatial;

/*
The waves are passed to the shader an array of arrays containing the parameters
that each wave moves in accordance to. Then the shader computes the displacement
and tangent vectors and applies them to the mesh.
*/

// Maximum number of waves that can be represented at any time
const int MAX_WAVES = 64;

// Dimensions of the mesh
uniform float width_x;
uniform float width_z;

// Options for visual appearance of waves
uniform vec3 ocean_color;
uniform bool show_domain_warping;
uniform bool show_lighting;
uniform bool show_foam;
uniform bool show_spray;

// Wave parameters
uniform int waves_num;
uniform vec4[MAX_WAVES] waves;


// Determines the dispersion relation
float dispersion(float k) {
    return sqrt(9.8 * k);
}

// Returns displacement and tangent vectors to the surface at a point x from the wave parameters.
vec3[3] singleGerstner(vec2 x, vec2 k, float A, float phase) {
	vec3[3] output;
	vec3 l_displacement;
	vec3 l_tangent_x;
	vec3 l_tangent_z;
	
	float magnitude = length(k);
	float theta = dot(k, x) - dispersion(magnitude) * TIME + phase;
	vec2 horizontal = -(k / magnitude) * A * sin(theta);
	float vertical = A * cos(theta);
	
	l_displacement = vec3(horizontal.x, vertical, horizontal.y);
	l_tangent_x = vec3(-(pow(k[0],2)/magnitude)*A*cos(theta), -A*k[0]*sin(theta), -k[0]*k[1]*A*cos(theta)/magnitude);
	l_tangent_z = vec3(-k[0]*k[1]*A*cos(theta)/magnitude, -A*k[1]*sin(theta), -(pow(k[1],2)/magnitude)*A*cos(theta));
	
	output[0] = l_displacement;
	output[1] = l_tangent_x;
	output[2] = l_tangent_z;

    return output;
}

// Takes a list of wave parameters and a number of them and generates the waves and tangents
vec3[3] multiGerstner(vec2 x, vec4[MAX_WAVES] list, int num){
	vec3[3] output;
	vec3[3] wave;
	output[0] = vec3(0.0);
	output[1] = vec3(0.0);
	output[2] = vec3(0.0);
	
	for (int i=0; i<num; i++){
		vec2 k = vec2(list[i][0],list[i][1]);
		wave = singleGerstner(x,k,list[i][2],list[i][3]);
		output[0] += wave[0];
		output[1] += wave[1];
		output[2] += wave[2];
	}
	return output;
}

// VERTEX Shader
void vertex() {
	// Read the original position before applying displacement.
	vec3[3] wave;
	// Wave tangent vectors
	vec3 tangent_x = vec3(1.0,0.0,0.0);
	vec3 tangent_z = vec3(0.0,0.0,1.0);
	// Take a reference to (x,z) coordinates
	vec2 x = VERTEX.xz;
	// Build the waves
	wave = multiGerstner(x,waves, waves_num);
	// Apply them to the mesh
	VERTEX += wave[0];
	
	// Compute normals
	tangent_x += wave[1];
	tangent_z += wave[2];
	NORMAL = normalize(cross(tangent_z, tangent_x));
}

// FRAGMENT Shader
void fragment() {
	// Called for every pixel the material is visible on.
	if(show_lighting == true){
		ROUGHNESS = 0.15;
		RIM = 2.0;
	}
	ALBEDO = ocean_color;
}

//void light() {
//	// Called for every pixel for every light affecting the material.
//	// Uncomment to replace the default light processing function with this one.
//}
