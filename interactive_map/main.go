package main

import (
	"context"
	"encoding/json"
	"fmt"
	"log"
	"net/http"
	"os"
	"time"

	"github.com/jackc/pgx/v4"
)

type Station struct {
	ID        string  `json:"id"`
	Name      string  `json:"name"`
	Latitude  float64 `json:"latitude"`
	Longitude float64 `json:"longitude"`
	Diesel    float64 `json:"diesel"`
	Time      string  `json:"time"`
}

var db *pgx.Conn
var query_closest_prices string
var logger = log.Default()

func loadQuery(filepath string) (string, error) {
	data, err := os.ReadFile(filepath)
	if err != nil {
		return "", err
	}
	return string(data), nil
}

func main() {
	var err error

	query_closest_prices, err = loadQuery("../sql/queries/closest_price.sql")
	if err != nil {
		log.Fatalf("Failed to load query: %v\n", err)
	}

	db, err = pgx.Connect(context.Background(), "postgres://client:client@localhost:5432/client")
	if err != nil {
		log.Fatalf("Unable to connect to database: %v\n", err)
	}
	defer db.Close(context.Background())

	http.HandleFunc("/", handleIndex)
	http.HandleFunc("/stations", handleStationList)

	log.Println("Server is running on http://localhost:8080")
	log.Fatal(http.ListenAndServe(":8080", nil))
}

func handleIndex(w http.ResponseWriter, r *http.Request) {
	http.ServeFile(w, r, "index.html")
}

func handleStationList(w http.ResponseWriter, r *http.Request) {
	logger.Println("Executing station list")
	if r.Method != http.MethodGet {
		http.Error(w, "Only GET method is supported", http.StatusMethodNotAllowed)
		return
	}

	// Read parameters from the request
	targetDateStr := r.URL.Query().Get("target_date")
	interval := r.URL.Query().Get("interval")

	if targetDateStr == "" || interval == "" {
		http.Error(w, "Missing required parameters: target_date and interval", http.StatusBadRequest)
		return
	}

	const layout = time.RFC3339
	targetDate, err := time.Parse(layout, targetDateStr)
	if err != nil {
		http.Error(w, "Invalid target_date format. Use RFC3339 format", http.StatusBadRequest)
		return
	}

	// Execute the SQL query with the provided parameters
	log.Println(targetDate, interval)
	rows, err := db.Query(context.Background(), query_closest_prices, targetDate, interval)
	if err != nil {
		http.Error(w, fmt.Sprintf("Database query failed: %v", err), http.StatusInternalServerError)
		return
	}
	defer rows.Close()

	// Collect results
	var stations []Station
	for rows.Next() {
		var station Station
		var dieselTime time.Time
		if err := rows.Scan(&station.ID, &station.Name, &station.Latitude, &station.Longitude, &station.Diesel, &dieselTime); err != nil {
			http.Error(w, fmt.Sprintf("Error scanning row: %v", err), http.StatusInternalServerError)
			return
		}
		station.Time = dieselTime.Format(time.RFC3339)
		stations = append(stations, station)
	}

	// Encode results as JSON
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(stations)
}
