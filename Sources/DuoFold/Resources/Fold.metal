#include <metal_stdlib>
using namespace metal;
struct Parameters { float progress; float perspective; float blur; float shadow; float style; float width; float height; float pad; };
struct VertexOut { float4 position [[position]]; float2 uv; };
// A projective surface hinged at the bottom edge. Homogeneous w preserves correct
// texture interpolation; the small quadratic bend avoids a rigid-card silhouette.
vertex VertexOut foldVertex(uint id [[vertex_id]], constant Parameters &p [[buffer(0)]]) {
    const uint columns=32, rows=64;
    const uint corners[6]={0,1,2,2,1,3};
    uint cell=id/6, corner=corners[id%6];
    float2 uv=float2(float(cell%columns + (corner%2))/columns, float(cell/columns + (corner/2))/rows);
    float distance=1-uv.y;
    float a=p.progress * 1.23 * p.perspective;
    float z=sin(a)*distance + sin(p.progress*M_PI_F)*0.055*distance*distance;
    float w=1+z*0.46*p.perspective;
    float h=distance*cos(a);
    VertexOut out;
    out.position=float4((uv.x*2-1), 2*h-w, 0, w);
    out.uv=uv;
    return out;
}
fragment float4 foldFragment(VertexOut in [[stage_in]], constant Parameters &p [[buffer(0)]],
 texture2d<float> sharp [[texture(0)]], texture2d<float> soft [[texture(1)]],
 texture2d<float> medium [[texture(2)]], texture2d<float> diffuse [[texture(3)]]) {
    constexpr sampler s(filter::linear, address::clamp_to_edge);
    float q=clamp(p.progress,0.0,1.0), d=1-in.uv.y;
    // Spatial, angle-driven defocus, not motion blur: a held lid stays blurred.
    float amount=pow(q,0.85)*pow(d,1.2)*p.blur;
    if(p.style>1.5) amount*=1.65;
    if(p.style>0.5 && p.style<1.5) amount*=0.3;
    float sigma=clamp(amount*54.0,0.0,28.0);
    float4 a=sharp.sample(s,in.uv), b=soft.sample(s,in.uv);
    float4 c=medium.sample(s,in.uv), e=diffuse.sample(s,in.uv);
    float4 color=sigma<2.5 ? mix(a,b,sigma/2.5) : sigma<9.0 ? mix(b,c,(sigma-2.5)/6.5) : mix(c,e,(sigma-9.0)/19.0);
    float shade=q*p.shadow*(0.12+0.65*pow(d,1.5));
    if(p.style>0.5 && p.style<1.5) shade*=1.5;
    color.rgb*=1-clamp(shade,0.0,0.9);
    if(p.style>1.5) color.rgb=mix(color.rgb,float3(0.78,0.83,0.88),amount*0.16);
    // Subtle grazing sheen; no hard seam, no bloom at the open endpoint.
    color.rgb+=sin(q*M_PI_F)*p.shadow*0.035*pow(d,3.0);
    color.rgb*=1-smoothstep(0.88,1.0,q);
    return float4(color.rgb,1);
}
