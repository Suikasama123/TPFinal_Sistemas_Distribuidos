package upb.distribuidos;

import com.google.gson.Gson;
import com.google.gson.JsonObject;
import io.grpc.ManagedChannel;
import io.grpc.ManagedChannelBuilder;
import okhttp3.*;
import org.eclipse.paho.client.mqttv3.*;

import java.io.IOException;
import java.net.InetAddress;
import java.util.UUID;
import java.util.concurrent.TimeUnit;

public class Worker {
    private static final String WORKER_LANGUAGE = "Java";
    private static String workerId;
    private static MqttClient mqttClient;
    private static String currentStatus = "idle";
    private static final Gson gson = new Gson();

    public static void main(String[] args) {
        try {
            // Generar Worker ID
            String hostname = InetAddress.getLocalHost().getHostName();
            workerId = String.format("java-worker-%s-%s", hostname, 
                UUID.randomUUID().toString().substring(0, 8));

            System.out.println("[WORKER] Iniciando " + workerId);
            System.out.println("[WORKER] Lenguaje: " + WORKER_LANGUAGE);

            // Esperar a que MQTT esté listo
            System.out.println("[WORKER] Esperando 5 segundos para que MQTT esté listo...");
            Thread.sleep(5000);

            // Configurar y conectar MQTT
            String broker = System.getenv().getOrDefault("MQTT_BROKER", "mosquitto");
            String port = System.getenv().getOrDefault("MQTT_PORT", "1883");
            String brokerUrl = String.format("tcp://%s:%s", broker, port);

            mqttClient = new MqttClient(brokerUrl, workerId);
            
            MqttConnectOptions options = new MqttConnectOptions();
            options.setCleanSession(true);

            mqttClient.setCallback(new MqttCallback() {
                @Override
                public void connectionLost(Throwable cause) {
                    System.err.println("[MQTT] Conexión perdida: " + cause.getMessage());
                }

                @Override
                public void messageArrived(String topic, MqttMessage message) {
                    handleMessage(topic, message);
                }

                @Override
                public void deliveryComplete(IMqttDeliveryToken token) {
                }
            });

            System.out.println("[MQTT] Conectando a " + brokerUrl);
            mqttClient.connect(options);

            System.out.println("[MQTT] Conectado al broker");
            publishLog("Worker " + workerId + " conectado al broker MQTT");

            // Suscribirse al tópico de tareas
            String taskTopic = "upb/workers/" + workerId + "/tasks";
            mqttClient.subscribe(taskTopic);
            System.out.println("[MQTT] Suscrito a " + taskTopic);

            // Registrarse con el master
            registerWorker();

            System.out.println("[WORKER] Worker en ejecución...");

            // Mantener vivo
            while (true) {
                Thread.sleep(1000);
            }

        } catch (Exception e) {
            System.err.println("[ERROR] Error fatal: " + e.getMessage());
            e.printStackTrace();
            System.exit(1);
        }
    }

    private static void handleMessage(String topic, MqttMessage message) {
        try {
            String payload = new String(message.getPayload());
            JsonObject taskData = gson.fromJson(payload, JsonObject.class);

            String query = taskData.get("query").getAsString();
            System.out.println("[TASK] Tarea recibida: " + 
                query.substring(0, Math.min(50, query.length())) + "...");

            processTask(taskData);

        } catch (Exception e) {
            System.err.println("[ERROR] Error al procesar mensaje: " + e.getMessage());
            e.printStackTrace();
        }
    }

    private static void registerWorker() {
        try {
            JsonObject register = new JsonObject();
            register.addProperty("worker_id", workerId);
            register.addProperty("language", WORKER_LANGUAGE);
            register.addProperty("status", "idle");
            register.addProperty("timestamp", System.currentTimeMillis());

            mqttClient.publish("upb/workers/register", 
                new MqttMessage(gson.toJson(register).getBytes()));
            
            publishLog("Worker " + workerId + " registrado");

        } catch (Exception e) {
            System.err.println("[ERROR] Error al registrar worker: " + e.getMessage());
        }
    }

    private static void updateStatus(String status) {
        try {
            currentStatus = status;
            
            JsonObject statusMsg = new JsonObject();
            statusMsg.addProperty("worker_id", workerId);
            statusMsg.addProperty("status", status);
            statusMsg.addProperty("timestamp", System.currentTimeMillis());

            mqttClient.publish("upb/workers/status", 
                new MqttMessage(gson.toJson(statusMsg).getBytes()));
            
            publishLog("Worker " + workerId + " cambió estado a: " + status);

        } catch (Exception e) {
            System.err.println("[ERROR] Error al actualizar estado: " + e.getMessage());
        }
    }

    private static void publishLog(String message) {
        try {
            JsonObject logMsg = new JsonObject();
            logMsg.addProperty("timestamp", System.currentTimeMillis());
            logMsg.addProperty("source", workerId);
            logMsg.addProperty("message", message);

            mqttClient.publish("upb/logs", 
                new MqttMessage(gson.toJson(logMsg).getBytes()));
            
            System.out.println("[LOG] " + message);

        } catch (Exception e) {
            System.err.println("[ERROR] Error al publicar log: " + e.getMessage());
        }
    }

    private static void processTask(JsonObject taskData) {
        publishLog("Worker " + workerId + " procesando tarea para sesión " + 
            taskData.get("session_id").getAsString());
        updateStatus("busy");

        long startTime = System.currentTimeMillis();

        try {
            // 1. Consultar a Gemini
            String query = taskData.get("query").getAsString();
            String apiKey = taskData.get("api_key").getAsString();
            String aiResponse = queryGemini(query, apiKey);

            // 2. Simular procesamiento largo
            simulateLongProcessing();

            // 3. Calcular tiempo de procesamiento
            long processingTime = System.currentTimeMillis() - startTime;

            // 4. Enviar resultado al master via gRPC
            String grpcEndpoint = taskData.get("grpc_endpoint").getAsString();
            sendResultToMaster(grpcEndpoint, taskData, aiResponse, processingTime);

            publishLog("Worker " + workerId + " completó tarea exitosamente");

        } catch (Exception e) {
            System.err.println("[ERROR] Error al procesar tarea: " + e.getMessage());
            e.printStackTrace();
            publishLog("Worker " + workerId + " error al procesar tarea: " + e.getMessage());
        } finally {
            updateStatus("idle");
        }
    }

    private static String queryGemini(String query, String apiKey) {
        try {
            publishLog("Worker " + workerId + " consultando a Gemini AI");

            OkHttpClient client = new OkHttpClient.Builder()
                .connectTimeout(30, TimeUnit.SECONDS)
                .readTimeout(30, TimeUnit.SECONDS)
                .build();

            String url = "https://generativelanguage.googleapis.com/v1beta/models/gemini-pro:generateContent?key=" + apiKey;

            JsonObject content = new JsonObject();
            JsonObject parts = new JsonObject();
            parts.addProperty("text", query);
            
            com.google.gson.JsonArray partsArray = new com.google.gson.JsonArray();
            partsArray.add(parts);
            
            JsonObject contentObj = new JsonObject();
            contentObj.add("parts", partsArray);
            
            com.google.gson.JsonArray contentsArray = new com.google.gson.JsonArray();
            contentsArray.add(contentObj);
            
            content.add("contents", contentsArray);

            RequestBody body = RequestBody.create(
                gson.toJson(content),
                MediaType.parse("application/json")
            );

            Request request = new Request.Builder()
                .url(url)
                .post(body)
                .build();

            try (Response response = client.newCall(request).execute()) {
                if (!response.isSuccessful()) {
                    return "Error al consultar Gemini: " + response.code();
                }

                String responseBody = response.body().string();
                JsonObject responseJson = gson.fromJson(responseBody, JsonObject.class);
                
                return responseJson
                    .getAsJsonArray("candidates").get(0)
                    .getAsJsonObject().getAsJsonObject("content")
                    .getAsJsonArray("parts").get(0)
                    .getAsJsonObject().get("text").getAsString();
            }

        } catch (Exception e) {
            String error = "Error al consultar Gemini: " + e.getMessage();
            publishLog(error);
            return error;
        }
    }

    private static void simulateLongProcessing() {
        try {
            int sleepTime = 10000; // 10 segundos
            publishLog("Worker " + workerId + " simulando procesamiento de " + sleepTime + "ms");
            Thread.sleep(sleepTime);
        } catch (InterruptedException e) {
            Thread.currentThread().interrupt();
        }
    }

    private static void sendResultToMaster(String endpoint, JsonObject taskData, 
                                          String aiResponse, long processingTime) {
        ManagedChannel channel = null;
        try {
            String[] parts = endpoint.split(":");
            String host = parts[0];
            int port = Integer.parseInt(parts[1]);

            channel = ManagedChannelBuilder
                .forAddress(host, port)
                .usePlaintext()
                .build();

            worker.WorkerCallbackGrpc.WorkerCallbackBlockingStub stub = 
                worker.WorkerCallbackGrpc.newBlockingStub(channel);

            worker.Worker.TaskResult result = worker.Worker.TaskResult.newBuilder()
                .setWorkerId(workerId)
                .setSessionId(taskData.get("session_id").getAsString())
                .setOriginalQuery(taskData.get("query").getAsString())
                .setAiResponse(aiResponse)
                .setApiKey(taskData.get("api_key").getAsString())
                .setProcessingTimeMs(processingTime)
                .setQueryTimestamp(taskData.get("timestamp").getAsLong())
                .setCompletionTimestamp(System.currentTimeMillis())
                .build();

            worker.Worker.ResultAck response = stub.sendResult(result);
            publishLog("Worker " + workerId + " envió resultado via gRPC: " + response.getMessage());

        } catch (Exception e) {
            System.err.println("[ERROR] Error al enviar resultado via gRPC: " + e.getMessage());
            e.printStackTrace();
            publishLog("Worker " + workerId + " error al enviar resultado: " + e.getMessage());
        } finally {
            if (channel != null) {
                try {
                    channel.shutdown().awaitTermination(5, TimeUnit.SECONDS);
                } catch (InterruptedException e) {
                    Thread.currentThread().interrupt();
                }
            }
        }
    }
}
