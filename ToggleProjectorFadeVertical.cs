using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class ToggleProjectorFadeVertical : MonoBehaviour
{
    [Header("Disables Projector Fade")]
    private Projector projector;

    private Material projectorMaterial;
    [SerializeField] private bool disableHorizontalFade = true;

    void Start()
    {
        projector = GetComponent<Projector>();
        projectorMaterial = new Material(projector.material);
        projector.material = projectorMaterial;
        if (disableHorizontalFade)
        {
            projectorMaterial.SetFloat("_HorizontalFade", 1f);
        }

    }
}
