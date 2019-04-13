using UnityEngine;
using UnityEngine.Rendering;
using UnityEditor;

public class RealityShader64GUI : ShaderGUI
{
    Material target;
    MaterialEditor editor;
    MaterialProperty[] properties;
    static GUIContent staticLabel = new GUIContent();

    bool _Cull = true;

    public override void OnGUI(MaterialEditor editor, MaterialProperty[] properties) {

        this.target = editor.target as Material;
        this.editor = editor;
        this.properties = properties;

        MaterialProperty _MainTex = FindProperty("_MainTex");
        MaterialProperty _AlphaCutoff = FindProperty("_AlphaCutoff");
        MaterialProperty _Transparency = FindProperty("_Transparency");
        MaterialProperty _N64 = FindProperty("_N64");

        MaterialProperty _GammaToLinear = FindProperty("_GammaToLinear");
        MaterialProperty _IgnoreVertexColor = FindProperty("_IgnoreVertexColor");

        MaterialProperty _Spec = FindProperty("_Spec");
        MaterialProperty _SpecColor = FindProperty("_SpecColor");
        MaterialProperty _Shininess = FindProperty("_Shininess");

        MaterialProperty _Emission = FindProperty("_Emission");
        MaterialProperty _EmissionTex = FindProperty("_EmissionTex");

        MaterialProperty _Overlay = FindProperty("_Overlay");
        MaterialProperty _UV = FindProperty("_UV");
        MaterialProperty _WorldPos = FindProperty("_WorldPos");
        MaterialProperty _Blend = FindProperty("_Blend");
        MaterialProperty _OverlayTex = FindProperty("_OverlayTex");
        MaterialProperty _ScrollSpeedX = FindProperty("_ScrollSpeedX");
        MaterialProperty _ScrollSpeedY = FindProperty("_ScrollSpeedY");

        MaterialProperty _SelfIllum = FindProperty("_SelfIllum");

        // rendering mode
        RenderingMode mode = RenderingMode.Opaque;
        if (target.IsKeywordEnabled("_RENDERING_CUTOUT")) {
            mode = RenderingMode.Cutout;
        } else if (target.IsKeywordEnabled("_RENDERING_FADE")) {
            mode = RenderingMode.Fade;
        } else if (target.IsKeywordEnabled("_RENDERING_TRANSPARENT")) {
            mode = RenderingMode.Transparent;
        }

        EditorGUI.BeginChangeCheck();
        mode = (RenderingMode)EditorGUILayout.EnumPopup(MakeLabel("Rendering Mode"), mode);
        if (EditorGUI.EndChangeCheck()) {
            editor.RegisterPropertyChangeUndo("Rendering Mode");

            if (mode == RenderingMode.Cutout) {
                target.EnableKeyword("_RENDERING_CUTOUT");
            } else {
                target.DisableKeyword("_RENDERING_CUTOUT");
            }
            if (mode == RenderingMode.Fade) {
                target.EnableKeyword("_RENDERING_FADE");
            } else {
                target.DisableKeyword("_RENDERING_FADE");
            }
            if (mode == RenderingMode.Transparent) {
                target.EnableKeyword("_RENDERING_TRANSPARENT");
            } else {
                target.DisableKeyword("_RENDERING_TRANSPARENT");
            }

            RenderingSettings settings = RenderingSettings.modes[(int)mode];

            foreach (Material m in editor.targets) {
                m.renderQueue = (int)settings.queue;
                m.SetOverrideTag("RenderType", settings.renderType);
                m.SetInt("_SrcBlend", (int)settings.srcBlend);
                m.SetInt("_DstBlend", (int)settings.dstBlend);
                m.SetInt("_ZWrite", settings.zWrite ? 1 : 0);
            }
        }

        // diffuse texture + tint
        GUILayout.Label("Main Texture", EditorStyles.boldLabel);

        editor.TexturePropertySingleLine(MakeLabel(_MainTex, "Diffuse (RGBA)"), _MainTex, FindProperty("_Tint"));
        if (target.IsKeywordEnabled("_RENDERING_CUTOUT")) {
            editor.ShaderProperty(_AlphaCutoff, MakeLabel(_AlphaCutoff));
        }else if (target.IsKeywordEnabled("_RENDERING_FADE") || target.IsKeywordEnabled("_RENDERING_TRANSPARENT")) {
            editor.ShaderProperty(_Transparency, MakeLabel(_Transparency));
        }
        editor.ShaderProperty(_N64, MakeLabel(_N64));
        editor.TextureScaleOffsetProperty(_MainTex);


        // vertex color options
        editor.ShaderProperty(_GammaToLinear, MakeLabel(_GammaToLinear));
        editor.ShaderProperty(_IgnoreVertexColor, MakeLabel(_IgnoreVertexColor));

        // specular
        editor.ShaderProperty(_Spec, MakeLabel(_Spec));
        if (_Spec.floatValue == 1) {
            editor.ShaderProperty(_SpecColor, MakeLabel(_SpecColor));
            editor.ShaderProperty(_Shininess, MakeLabel(_Shininess));
        }

        // emission
        editor.ShaderProperty(_Emission, MakeLabel(_Emission));
        if (_Emission.floatValue == 1) {
            editor.TexturePropertySingleLine(MakeLabel(_EmissionTex, "Emission (RGB)"), _EmissionTex, FindProperty("_EmissionColor"));
            editor.TextureScaleOffsetProperty(_EmissionTex);
        }

        // overlay texture
        editor.ShaderProperty(_Overlay, MakeLabel(_Overlay));
        if (_Overlay.floatValue != 0) {
            editor.TexturePropertySingleLine(MakeLabel(_OverlayTex, "Overlay Texture (RGB)"), _OverlayTex, FindProperty("_OverlayColor"));
            editor.ShaderProperty(_Blend, MakeLabel(_Blend));
            EditorGUI.indentLevel += 2;
            editor.ShaderProperty(_UV, MakeLabel(_UV));
            
            if (_UV.floatValue > 2) {
                editor.ShaderProperty(_WorldPos, MakeLabel(_WorldPos));
            }
            
            editor.TextureScaleOffsetProperty(_OverlayTex);

            editor.ShaderProperty(_ScrollSpeedX, MakeLabel(_ScrollSpeedX));
            editor.ShaderProperty(_ScrollSpeedY, MakeLabel(_ScrollSpeedY));

            EditorGUI.indentLevel -= 2;
        }

        // lighting
        editor.ShaderProperty(_SelfIllum, MakeLabel(_SelfIllum));

        // other
        GUILayout.Label("Other", EditorStyles.boldLabel);

        EditorGUI.BeginChangeCheck();
        _Cull = (bool)EditorGUILayout.Toggle("Backface Culling", _Cull);
        if (EditorGUI.EndChangeCheck()) {
            editor.RegisterPropertyChangeUndo("Backface Culling");

            foreach (Material m in editor.targets) {
                m.SetInt("_Cull", _Cull ? (int)CullMode.Back : (int)CullMode.Off);
            }
        }
        
    }

    MaterialProperty FindProperty(string name) {
        return FindProperty(name, properties);
    }

    static GUIContent MakeLabel(string text, string tooltip = null) {
        staticLabel.text = text;
        staticLabel.tooltip = tooltip;
        return staticLabel;
    }

    static GUIContent MakeLabel (MaterialProperty property, string tooltip = null) {
        staticLabel.text = property.displayName;
        staticLabel.tooltip = tooltip;
        return staticLabel;
    }

    enum RenderingMode {
        Opaque, Cutout, Fade, Transparent
    }

    struct RenderingSettings {
        public RenderQueue queue;
        public string renderType;
        public BlendMode srcBlend, dstBlend;
        public bool zWrite;

        public static RenderingSettings[] modes = {
            new RenderingSettings() {
                queue = RenderQueue.Geometry,
                renderType = "",
                srcBlend = BlendMode.One,
                dstBlend = BlendMode.Zero,
                zWrite = true
            },
            new RenderingSettings() {
                queue = RenderQueue.AlphaTest,
                renderType = "TransparentCutout",
                srcBlend = BlendMode.One,
                dstBlend = BlendMode.Zero,
                zWrite = true
            },
            new RenderingSettings() {
                queue = RenderQueue.Transparent,
                renderType = "Transparent",
                srcBlend = BlendMode.SrcAlpha,
                dstBlend = BlendMode.OneMinusSrcAlpha,
                zWrite = false
            },
            new RenderingSettings() {
                queue = RenderQueue.Transparent,
                renderType = "Transparent",
                srcBlend = BlendMode.One,
                dstBlend = BlendMode.OneMinusSrcAlpha,
                zWrite = false
            }
        };
    }
}
