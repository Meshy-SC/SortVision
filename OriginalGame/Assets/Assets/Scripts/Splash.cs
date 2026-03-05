

using System;
using System.Collections;
using dotmob;
using UnityEngine;
//using OneSignalSDK;

public class Splash : MonoBehaviour
{
    private IEnumerator Start()
    {

        // Replace 'YOUR_ONESIGNAL_APP_ID' with your OneSignal App ID from app.onesignal.com
        //OneSignal.Default.Initialize("YOUR_ONESIGNAL_APP_ID");

        if (!AdsManager.HaveSetupConsent)
        {
            SharedUIManager.ConsentPanel.Show();
            yield return new WaitUntil(() => !SharedUIManager.ConsentPanel.Showing);
        }

        GameManager.LoadScene("MainMenu");
    }
}