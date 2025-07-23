using System.Collections;
using Unity.Sentis;
using UnityEngine;
using UnityEngine.UI;

//I referenced the two articles below, i recommend reading them
//reference1: https://github.com/PeterL1n/RobustVideoMatting/blob/master/documentation/inference.md
//reference2: https://docs.unity3d.com/Packages/com.unity.sentis@2.1/manual/use-model-output.html
public class VideoMatting : MonoBehaviour
{

    [SerializeField] private ModelAsset modelAsset;
    [SerializeField] private RawImage[] targetRawImages;

    private RenderTexture _sourceTexture;
    private RenderTexture _foregroundTexture;
    private RenderTexture _alphaTexture;
    private Worker _worker;
    private Model _runtimeModel;

    private Tensor<float> _r1, _r2, _r3, _r4, _inputTensor, _downsampleRatioTensor;

    void Awake()
    {
        //initialize model
        _runtimeModel = ModelLoader.Load(modelAsset);
        _worker = new Worker(_runtimeModel, BackendType.GPUCompute);
        _r1 = new Tensor<float>(new TensorShape(1, 1, 1, 1), new float[] { 0.0f });
        _r2 = new Tensor<float>(new TensorShape(1, 1, 1, 1), new float[] { 0.0f });
        _r3 = new Tensor<float>(new TensorShape(1, 1, 1, 1), new float[] { 0.0f });
        _r4 = new Tensor<float>(new TensorShape(1, 1, 1, 1), new float[] { 0.0f });
        _inputTensor = new Tensor<float>(new TensorShape(1, 3, 1, 1));
        _downsampleRatioTensor = new Tensor<float>(new TensorShape(1), new float[] { 1.0f });
    }

    void Start()
    {
        StartCoroutine(ProcessVideoMatting());
    }

    public void SetSourceTexture(RenderTexture sourceTexture)
    {
        _sourceTexture = sourceTexture;
    }

    IEnumerator ProcessVideoMatting()
    {
        while (true)
        {
            if (_sourceTexture == null)
            {
                yield return null;
                continue;
            }

            int textureWidth = _sourceTexture.width;
            int textureHeight = _sourceTexture.height;


            float optimalRatio = CalculateOptimalDownsampleRatio(textureWidth, textureHeight); // get downsaple ratio
            var inputShape = new TensorShape(1, 3, textureHeight, textureWidth); // batch, channel, height, width
            if (_inputTensor == null || !_inputTensor.shape.Equals(inputShape))
            {
                _inputTensor?.Dispose();
                _inputTensor = new Tensor<float>(inputShape);
            }
            TextureConverter.ToTensor(_sourceTexture, _inputTensor, new TextureTransform());
            _downsampleRatioTensor[0] = optimalRatio;

            _worker.SetInput("src", _inputTensor);
            _worker.SetInput("r1i", _r1);
            _worker.SetInput("r2i", _r2);
            _worker.SetInput("r3i", _r3);
            _worker.SetInput("r4i", _r4);
            _worker.SetInput("downsample_ratio", _downsampleRatioTensor);
            _worker.Schedule();

            yield return null;

            var foregroundTensor = _worker.PeekOutput("fgr") as Tensor<float>;
            var alphaTensor = _worker.PeekOutput("pha") as Tensor<float>;

            GetOrCreateRenderTexture(ref _foregroundTexture, textureWidth, textureHeight, "ForegroundRT");
            GetOrCreateRenderTexture(ref _alphaTexture, textureWidth, textureHeight, "AlphaRT");

            var fgrAwaiter = foregroundTensor.ReadbackAndCloneAsync().GetAwaiter();
            var alphaAwaiter = alphaTensor.ReadbackAndCloneAsync().GetAwaiter();

            while (!fgrAwaiter.IsCompleted || !alphaAwaiter.IsCompleted)
            {
                yield return null;
            }

            using (var foregroundOut = fgrAwaiter.GetResult())
            using (var alphaOut = alphaAwaiter.GetResult())
            {
                TextureConverter.RenderToTexture(foregroundTensor, _foregroundTexture);
                TextureConverter.RenderToTexture(alphaTensor, _alphaTexture);
            }
            
            try
            {
                foreach (var rawImage in targetRawImages)
                {
                    rawImage.material.SetTexture("_FgrTex", _foregroundTexture);
                    rawImage.material.SetTexture("_PhaTex", _alphaTexture);
                }
            }
            catch (System.Exception e)
            {
                Debug.LogError("NOTE: Please make sure the RawImage has a material using the VideoMatting shader. Exception: " + e.Message);
            }
        }
    }

    private RenderTexture GetOrCreateRenderTexture(ref RenderTexture renderTexture, int width, int height, string name)
    {
        if (renderTexture == null || renderTexture.width != width || renderTexture.height != height)
        {
            if (renderTexture != null)
            {
                renderTexture.Release();
                DestroyImmediate(renderTexture);
            }

            renderTexture = new RenderTexture(width, height, 0, RenderTextureFormat.ARGB32);
            renderTexture.name = name;
            renderTexture.Create();
        }

        return renderTexture;
    }


    // | Resolution    | Portrait      | Full-Body      |
    // | ------------- | ------------- | -------------- |
    // | <= 512x512    | 1             | 1              |
    // | 1280x720      | 0.375         | 0.6            |
    // | 1920x1080     | 0.25          | 0.4            |
    // | 3840x2160     | 0.125         | 0.2            |
    private float CalculateOptimalDownsampleRatio(int width, int height)
    {
        int imagePixelCount = width * height;

        if (imagePixelCount <= 512 * 512)
        {
            return 1.0f;     // 원본 크기 유지
        }
        else if (imagePixelCount <= 1280 * 720)
        {
            return 0.6f;
        }
        else if (imagePixelCount <= 1920 * 1080)
        {
            return 0.4f;
        }
        else if (imagePixelCount <= 3840 * 2160)
        {
            return 0.2f;
        }
        else
        {
            return 0.1f;
        }
    }

    void OnDestroy()
    {
        _r1?.Dispose();
        _r2?.Dispose();
        _r3?.Dispose();
        _r4?.Dispose();
        _inputTensor?.Dispose();
        _downsampleRatioTensor?.Dispose();
        _worker?.Dispose();
    }
}