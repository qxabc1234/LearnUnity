using System;
using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class BackpackBehaviourScript : MonoBehaviour
{
    public bool pressed = false;
    public float roll = 0.0f;
    public float pitch = 0.0f;
    public float lastX = 0.0f;
    public float lastY = 0.0f;
    private Transform trans;
    private new Camera camera;

    // Start is called before the first frame update
    void Start()
    {
        trans = GetComponent<Transform>();
        camera = FindObjectOfType<Camera>();
    }

    // Update is called once per frame
    void Update()
    {
        mouse_button_callback();
        mouse_callback();

        var rotateY = Quaternion.AngleAxis(pitch, camera.cameraToWorldMatrix * Vector3.up);
        var rotateX = Quaternion.AngleAxis(roll, camera.cameraToWorldMatrix * Vector3.right);
        trans.rotation = rotateX * rotateY;
    }

    void mouse_callback()
    {
        Vector3 mousePos = Input.mousePosition;

        if (pressed)
        {

            float xoffset = mousePos.x - lastX;
            float yoffset = mousePos.y - lastY;
            lastX = mousePos.x;
            lastY = mousePos.y;

            float ratio = 0.3f;
            this.pitch -= xoffset * ratio;
            this.roll += yoffset * ratio;
            if (this.roll < -90.0f) this.roll = -90.0f;
            if (this.roll > 90.0f) this.roll = 90.0f;

        }

    }

    void mouse_button_callback()
    {

        if (Input.GetMouseButtonDown(0))
        {
            Debug.Log("Pressed left-click.");
            if (!pressed)
            {
                Vector3 mousePos = Input.mousePosition;
                lastX = mousePos.x;
                lastY = mousePos.y;

                pressed = true;
            }
        }

        if (Input.GetMouseButtonUp(0))
        {
            if (pressed)
            {
                pressed = false;
            }
        }

    }
}
