using UnityEngine;
using UnityEngine.UI;
using UnityEngine.Video;

public class VideoPlayerController : MonoBehaviour
{
    [SerializeField] private VideoPlayer videoPlayer;
    [SerializeField] private VideoMatting videoMatting;
    [SerializeField] private RawImage originalRawImage;
    
    private RenderTexture renderTexture;

    void Start()
    {
        if (videoPlayer.clip != null)
        {
            SetupRenderTexture();
            videoPlayer.prepareCompleted += OnVideoPrepared;
            videoPlayer.Prepare();
        }
    }

    void SetupRenderTexture()
    {
        int width = (int)videoPlayer.clip.width;
        int height = (int)videoPlayer.clip.height;
        
        renderTexture = new RenderTexture(width, height, 0);
        renderTexture.Create();
        
        videoPlayer.renderMode = VideoRenderMode.RenderTexture;
        videoPlayer.targetTexture = renderTexture;

        originalRawImage.texture = renderTexture;
    }

    void OnVideoPrepared(VideoPlayer vp)
    {
        videoMatting.SetSourceTexture(renderTexture);
        videoPlayer.Play();
    }

    void OnDestroy()
    {
        if (renderTexture != null)
        {
            renderTexture.Release();
        }
    }
} 