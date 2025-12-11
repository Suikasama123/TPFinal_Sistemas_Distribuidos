package main

import (
	"context"
	"encoding/json"
	"fmt"
	"log"
	"os"
	"os"
	"time"

	mqtt "github.com/eclipse/paho.mqtt.golang"
	genai "github.com/google/generative-ai-go/genai"
	"github.com/google/uuid"
	"google.golang.org/grpc"
	"google.golang.org/grpc/credentials/insecure"

	pb "worker-go/pb"
)

type TaskData struct {
	WorkerID     string `json:"worker_id"`
	SessionID    string `json:"session_id"`
	Query        string `json:"query"`
	APIKey       string `json:"api_key"`
	GRPCEndpoint string `json:"grpc_endpoint"`
	Timestamp    int64  `json:"timestamp"`
}

type LogMessage struct {
	Timestamp int64  `json:"timestamp"`
	Source    string `json:"source"`
	Message   string `json:"message"`
}

var (
	workerID      string
	mqttClient    mqtt.Client
	currentStatus = "idle"
)

const (
	workerLanguage = "Go"
)

func main() {
	hostname, _ := os.Hostname()
	workerID = fmt.Sprintf("go-worker-%s-%s", hostname, uuid.New().String()[:8])

	log.Printf("[WORKER] Iniciando %s\n", workerID)
	log.Printf("[WORKER] Lenguaje: %s\n", workerLanguage)

	// Esperar a que MQTT esté listo
	log.Println("[WORKER] Esperando 5 segundos para que MQTT esté listo...")
	time.Sleep(5 * time.Second)

	// Configurar y conectar MQTT
	broker := getEnv("MQTT_BROKER", "mosquitto")
	port := getEnv("MQTT_PORT", "1883")
	brokerURL := fmt.Sprintf("tcp://%s:%s", broker, port)

	opts := mqtt.NewClientOptions()
	opts.AddBroker(brokerURL)
	opts.SetClientID(workerID)
	opts.SetDefaultPublishHandler(messageHandler)
	opts.OnConnect = onConnect

	mqttClient = mqtt.NewClient(opts)
	if token := mqttClient.Connect(); token.Wait() && token.Error() != nil {
		log.Fatalf("[MQTT] Error de conexión: %v\n", token.Error())
	}

	log.Println("[WORKER] Worker en ejecución...")
	select {} // Mantener vivo
}

func onConnect(client mqtt.Client) {
	log.Println("[MQTT] Conectado al broker")
	publishLog(fmt.Sprintf("Worker %s conectado al broker MQTT", workerID))

	// Suscribirse al tópico de tareas
	topic := fmt.Sprintf("upb/workers/%s/tasks", workerID)
	if token := client.Subscribe(topic, 0, taskHandler); token.Wait() && token.Error() != nil {
		log.Printf("[MQTT] Error al suscribirse: %v\n", token.Error())
		return
	}
	log.Printf("[MQTT] Suscrito a %s\n", topic)

	// Registrarse con el master
	registerWorker()
}

func messageHandler(client mqtt.Client, msg mqtt.Message) {
	log.Printf("[MQTT] Mensaje recibido en %s\n", msg.Topic())
}

func taskHandler(client mqtt.Client, msg mqtt.Message) {
	var task TaskData
	if err := json.Unmarshal(msg.Payload(), &task); err != nil {
		log.Printf("[ERROR] Error al parsear tarea: %v\n", err)
		return
	}

	log.Printf("[TASK] Tarea recibida: %s...\n", task.Query[:min(50, len(task.Query))])
	processTask(task)
}

func registerWorker() {
	register := map[string]interface{}{
		"worker_id": workerID,
		"language":  workerLanguage,
		"status":    "idle",
		"timestamp": time.Now().UnixMilli(),
	}

	data, _ := json.Marshal(register)
	mqttClient.Publish("upb/workers/register", 0, false, data)
	publishLog(fmt.Sprintf("Worker %s registrado", workerID))
}

func updateStatus(status string) {
	currentStatus = status
	statusMsg := map[string]interface{}{
		"worker_id": workerID,
		"status":    status,
		"timestamp": time.Now().UnixMilli(),
	}

	data, _ := json.Marshal(statusMsg)
	mqttClient.Publish("upb/workers/status", 0, false, data)
	publishLog(fmt.Sprintf("Worker %s cambió estado a: %s", workerID, status))
}

func publishLog(message string) {
	logMsg := LogMessage{
		Timestamp: time.Now().UnixMilli(),
		Source:    workerID,
		Message:   message,
	}

	data, _ := json.Marshal(logMsg)
	mqttClient.Publish("upb/logs", 0, false, data)
	log.Printf("[LOG] %s\n", message)
}

func processTask(task TaskData) {
	publishLog(fmt.Sprintf("Worker %s procesando tarea para sesión %s", workerID, task.SessionID))
	updateStatus("busy")

	startTime := time.Now()

	defer func() {
		updateStatus("idle")
	}()

	// 1. Consultar a Gemini
	aiResponse, err := queryGemini(task.Query, task.APIKey)
	if err != nil {
		aiResponse = fmt.Sprintf("Error: %v", err)
		publishLog(fmt.Sprintf("Worker %s error al consultar Gemini: %v", workerID, err))
	}

	// 2. Simular procesamiento largo
	simulateLongProcessing()

	// 3. Calcular tiempo de procesamiento
	processingTime := time.Since(startTime).Milliseconds()

	// 4. Enviar resultado al master via gRPC
	result := &pb.TaskResult{
		WorkerId:             workerID,
		SessionId:            task.SessionID,
		OriginalQuery:        task.Query,
		AiResponse:           aiResponse,
		ApiKey:               task.APIKey,
		ProcessingTimeMs:     processingTime,
		QueryTimestamp:       task.Timestamp,
		CompletionTimestamp:  time.Now().UnixMilli(),
	}

	if err := sendResultToMaster(task.GRPCEndpoint, result); err != nil {
		publishLog(fmt.Sprintf("Worker %s error al enviar resultado: %v", workerID, err))
	} else {
		publishLog(fmt.Sprintf("Worker %s completó tarea exitosamente", workerID))
	}
}

func queryGemini(query, apiKey string) (string, error) {
	ctx := context.Background()
	client, err := genai.NewClient(ctx, genai.WithAPIKey(apiKey))
	if err != nil {
		return "", err
	}
	defer client.Close()

	publishLog(fmt.Sprintf("Worker %s consultando a Gemini AI", workerID))

	model := client.GenerativeModel("gemini-pro")
	resp, err := model.GenerateContent(ctx, genai.Text(query))
	if err != nil {
		return "", err
	}

	if len(resp.Candidates) == 0 || len(resp.Candidates[0].Content.Parts) == 0 {
		return "Sin respuesta de Gemini", nil
	}

	return fmt.Sprintf("%v", resp.Candidates[0].Content.Parts[0]), nil
}

func simulateLongProcessing() {
	sleepTime := 10 * time.Second
	publishLog(fmt.Sprintf("Worker %s simulando procesamiento de %v", workerID, sleepTime))
	time.Sleep(sleepTime)
}

func sendResultToMaster(endpoint string, result *pb.TaskResult) error {
	conn, err := grpc.Dial(endpoint, grpc.WithTransportCredentials(insecure.NewCredentials()))
	if err != nil {
		return err
	}
	defer conn.Close()

	client := pb.NewWorkerCallbackClient(conn)
	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()

	response, err := client.SendResult(ctx, result)
	if err != nil {
		return err
	}

	publishLog(fmt.Sprintf("Worker %s envió resultado via gRPC: %s", workerID, response.Message))
	return nil
}

func getEnv(key, defaultValue string) string {
	if value := os.Getenv(key); value != "" {
		return value
	}
	return defaultValue
}

func min(a, b int) int {
	if a < b {
		return a
	}
	return b
}
