using System;
using System.Net.Http;
using System.Net.Http.Json;
using System.Reflection.Metadata;
using System.Runtime.CompilerServices;
using System.Text.Json;
using System.Text.Json.Serialization;
using System.Threading.Tasks;
using Azure;
using Azure.Messaging.ServiceBus;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Configuration.Json;

class Program
{
    private static HttpClient client = new HttpClient();
    private static ServiceBusClient serviceBusClient;
    private static ServiceBusSender sender;
    private static int x = 0;
    private static int numberOfTasks;


    static async Task Main(string[] args)
    {
        var configuration = new ConfigurationBuilder()
               .AddJsonFile("appsettings.json", optional: false, reloadOnChange: true)
               .AddEnvironmentVariables()
               .AddCommandLine(args)
               .Build();

        int requests;
        string type;

        if (args.Length < 2)
        {
            Console.WriteLine("Usage: <http|queue> <requests> [<numberOfTasks>]");
            return;
        }
        else
        {
            
            type = args[0];
            requests = int.Parse(args[1]);
            numberOfTasks = args.Length > 2 ? int.Parse(args[2]) : 10;

            Console.WriteLine($"Sending {Convert.ToInt32(args[1]) * numberOfTasks} messages using {args[0]}");

            if (type == "queue")
            {
                serviceBusClient = new ServiceBusClient(configuration["servicebus:connectionString"]);
                sender = serviceBusClient.CreateSender(configuration["servicebus:queueName"]);
            }

            var tasks = new Task[numberOfTasks];
            for (int i = 0; i < numberOfTasks; i++)
            {
                tasks[i] = Task.Run(async () =>
                {
                    for (int j = 0; j < requests; j++)
                    {
                        var msg = new Message { dt = DateTime.UtcNow, text = "Hello, PlatformCon!", id = j };
                        if (type == "http") { 
                            var response = await client.PostAsJsonAsync(configuration["url"], new Message { dt = DateTime.UtcNow, text = "Hello, PlatformCon!", id = j });
                            Console.WriteLine($"Status Code: {response.StatusCode}, Body: {await response.Content.ReadAsStringAsync()}");
                        }
                        else if (type == "queue")
                        {
                            string messageBody = JsonSerializer.Serialize(msg);
                            ServiceBusMessage serviceBusMessage = new ServiceBusMessage(messageBody);
                            await sender.SendMessageAsync(serviceBusMessage);
                            Console.WriteLine($"Message sent: {x}");
                        }
                        x++;
                    }
                    await Task.Delay(1000);
                }
                );
            }
            Task.WaitAll(tasks);
        }
        Console.WriteLine($"Total messages sent: {x} by {numberOfTasks} task(s).");
        Console.WriteLine("Press any key to exit...");
        Console.Read();
    }
}


    

class Message
{
    public DateTime dt { get; set; }
    public string text { get; set; }
    public int id { get; set; }
}