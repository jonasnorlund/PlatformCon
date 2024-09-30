using Microsoft.AspNetCore.Mvc;

namespace AcaApi.Controllers
{
    [ApiController]
    [Route("[action]")]
    public class AcaApiController : ControllerBase
    {
        private readonly ILogger<AcaApiController> _logger;

        public AcaApiController(ILogger<AcaApiController> logger)
        {
            _logger = logger;
        }

        [HttpPost(Name = "PostMessage")]
        public IActionResult PostMessage(Message msg)
        {
            Console.WriteLine($"Http received: {msg.text}, id: {msg.id} @ {Environment.GetEnvironmentVariable("CONTAINER_APP_REPLICA_NAME")}");
            msg.text = $"{msg.text} @ {Environment.GetEnvironmentVariable("CONTAINER_APP_REPLICA_NAME")}";
            return Ok(msg);
        }

        [HttpPost(Name = "ProcessMessage")]
        public void ProcessMessage(Message msg)
        {
            Console.WriteLine($"Message processed: {msg.text}, id: {msg.id}");
        }
    }

    public class Message
    {
        public DateTime dt { get; set; }
        public string ?text { get; set; }
        public int id { get; set; }
    }
}
