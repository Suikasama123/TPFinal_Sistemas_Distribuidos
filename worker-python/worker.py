import os
import sys
import time
import json
import uuid
import socket
import paho.mqtt.client as mqtt
import grpc
import google.generativeai as genai
from datetime import datetime

# Importar proto generado
import worker_pb2
import worker_pb2_grpc

# Configuración
WORKER_ID = f"python-worker-{socket.gethostname()}-{uuid.uuid4().hex[:8]}"
MQTT_BROKER = os.getenv('MQTT_BROKER', 'mosquitto')
MQTT_PORT = int(os.getenv('MQTT_PORT', '1883'))
WORKER_LANGUAGE = "Python"

# Estado del worker
current_status = "idle"
mqtt_client = None

def publish_log(message):
    """Publicar log en MQTT"""
    if mqtt_client and mqtt_client.is_connected():
        log_msg = {
            'timestamp': int(time.time() * 1000),
            'source': WORKER_ID,
            'message': message
        }
        mqtt_client.publish('upb/logs', json.dumps(log_msg))
        print(f"[LOG] {message}")

def register_worker():
    """Registrar worker con el master"""
    register_msg = {
        'worker_id': WORKER_ID,
        'language': WORKER_LANGUAGE,
        'status': 'idle',
        'timestamp': int(time.time() * 1000)
    }
    mqtt_client.publish('upb/workers/register', json.dumps(register_msg))
    publish_log(f"Worker {WORKER_ID} registrado")

def update_status(status):
    """Actualizar estado del worker"""
    global current_status
    current_status = status
    status_msg = {
        'worker_id': WORKER_ID,
        'status': status,
        'timestamp': int(time.time() * 1000)
    }
    mqtt_client.publish('upb/workers/status', json.dumps(status_msg))
    publish_log(f"Worker {WORKER_ID} cambió estado a: {status}")

def query_gemini(query, api_key):
    """Realizar consulta a Gemini AI"""
    try:
        genai.configure(api_key=api_key)
        model = genai.GenerativeModel('gemini-pro')
        
        publish_log(f"Worker {WORKER_ID} consultando a Gemini AI")
        response = model.generate_content(query)
        
        return response.text
    except Exception as e:
        error_msg = f"Error al consultar Gemini: {str(e)}"
        publish_log(error_msg)
        return f"Error: {error_msg}"

def simulate_long_processing():
    """Simular procesamiento largo (10 segundos como en el enunciado)"""
    sleep_time = 10
    publish_log(f"Worker {WORKER_ID} simulando procesamiento de {sleep_time}s")
    time.sleep(sleep_time)

def send_result_to_master(grpc_endpoint, result_data):
    """Enviar resultado al master via gRPC"""
    try:
        channel = grpc.insecure_channel(grpc_endpoint)
        stub = worker_pb2_grpc.WorkerCallbackStub(channel)
        
        result = worker_pb2.TaskResult(
            worker_id=result_data['worker_id'],
            session_id=result_data['session_id'],
            original_query=result_data['original_query'],
            ai_response=result_data['ai_response'],
            api_key=result_data['api_key'],
            processing_time_ms=result_data['processing_time_ms'],
            query_timestamp=result_data['query_timestamp'],
            completion_timestamp=result_data['completion_timestamp']
        )
        
        response = stub.SendResult(result)
        publish_log(f"Worker {WORKER_ID} envió resultado via gRPC: {response.message}")
        
        channel.close()
        return response.success
    except Exception as e:
        error_msg = f"Error al enviar resultado via gRPC: {str(e)}"
        publish_log(error_msg)
        print(f"[ERROR] {error_msg}", file=sys.stderr)
        return False

def process_task(task_data):
    """Procesar una tarea asignada"""
    publish_log(f"Worker {WORKER_ID} procesando tarea para sesión {task_data['session_id']}")
    update_status('busy')
    
    start_time = time.time()
    
    try:
        # 1. Consultar a Gemini
        ai_response = query_gemini(task_data['query'], task_data['api_key'])
        
        # 2. Simular procesamiento largo
        simulate_long_processing()
        
        # 3. Calcular tiempo de procesamiento
        end_time = time.time()
        processing_time_ms = int((end_time - start_time) * 1000)
        
        # 4. Preparar resultado
        result_data = {
            'worker_id': WORKER_ID,
            'session_id': task_data['session_id'],
            'original_query': task_data['query'],
            'ai_response': ai_response,
            'api_key': task_data['api_key'],
            'processing_time_ms': processing_time_ms,
            'query_timestamp': task_data['timestamp'],
            'completion_timestamp': int(time.time() * 1000)
        }
        
        # 5. Enviar resultado al master via gRPC
        success = send_result_to_master(task_data['grpc_endpoint'], result_data)
        
        if success:
            publish_log(f"Worker {WORKER_ID} completó tarea exitosamente")
        else:
            publish_log(f"Worker {WORKER_ID} completó tarea pero hubo error en callback")
        
    except Exception as e:
        error_msg = f"Error al procesar tarea: {str(e)}"
        publish_log(error_msg)
        print(f"[ERROR] {error_msg}", file=sys.stderr)
    finally:
        # Marcar como disponible
        update_status('idle')

def on_connect(client, userdata, flags, rc):
    """Callback cuando se conecta a MQTT"""
    if rc == 0:
        print(f"[MQTT] Conectado al broker")
        publish_log(f"Worker {WORKER_ID} conectado al broker MQTT")
        
        # Suscribirse al tópico de tareas para este worker
        client.subscribe(f'upb/workers/{WORKER_ID}/tasks')
        print(f"[MQTT] Suscrito a upb/workers/{WORKER_ID}/tasks")
        
        # Registrarse con el master
        register_worker()
    else:
        print(f"[MQTT] Error de conexión: {rc}", file=sys.stderr)

def on_message(client, userdata, msg):
    """Callback cuando se recibe un mensaje MQTT"""
    try:
        task_data = json.loads(msg.payload.decode())
        print(f"[TASK] Tarea recibida: {task_data['query'][:50]}...")
        
        # Procesar tarea
        process_task(task_data)
        
    except Exception as e:
        error_msg = f"Error al procesar mensaje: {str(e)}"
        print(f"[ERROR] {error_msg}", file=sys.stderr)
        publish_log(error_msg)

def main():
    """Función principal"""
    global mqtt_client
    
    print(f"[WORKER] Iniciando {WORKER_ID}")
    print(f"[WORKER] Lenguaje: {WORKER_LANGUAGE}")
    
    # Esperar a que MQTT esté listo
    print("[WORKER] Esperando 5 segundos para que MQTT esté listo...")
    time.sleep(5)
    
    # Configurar cliente MQTT
    mqtt_client = mqtt.Client(client_id=WORKER_ID)
    mqtt_client.on_connect = on_connect
    mqtt_client.on_message = on_message
    
    # Conectar a broker
    try:
        print(f"[MQTT] Conectando a {MQTT_BROKER}:{MQTT_PORT}")
        mqtt_client.connect(MQTT_BROKER, MQTT_PORT, 60)
        
        # Loop infinito
        mqtt_client.loop_forever()
        
    except KeyboardInterrupt:
        print("\n[WORKER] Deteniendo worker...")
        publish_log(f"Worker {WORKER_ID} detenido")
        mqtt_client.disconnect()
    except Exception as e:
        print(f"[ERROR] Error fatal: {str(e)}", file=sys.stderr)
        sys.exit(1)

if __name__ == '__main__':
    main()
