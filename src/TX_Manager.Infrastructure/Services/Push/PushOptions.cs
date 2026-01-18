namespace TX_Manager.Infrastructure.Services.Push;

public class PushOptions
{
    public FcmOptions Fcm { get; set; } = new();

    public class FcmOptions
    {
        public bool Enabled { get; set; } = false;

        // Legacy FCM server key approach (easy to wire, still common)
        public string? ServerKey { get; set; }

        // Optional: override endpoint
        public string Endpoint { get; set; } = "https://fcm.googleapis.com/fcm/send";
    }
}

