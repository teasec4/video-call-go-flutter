package config

import (
	"os"
	// "time"

	"github.com/joho/godotenv"
)

type Config struct{
	DBUrl string
	ServerPort string
	JWTSecret string
	JWTExpiresIn string // time.Duration 
}

func LoadConfig() *Config{
	godotenv.Load()
	return &Config{
		DBUrl: getEnv("DBUrl", ""),
		ServerPort: getEnv("ServerPort", "8081"),
		JWTSecret: getEnv("JWTSecret", ""),
		JWTExpiresIn: getEnv("JWTExpiresIn", ""),
	}
}

func getEnv(key, fallback string) string{
	if value, ok := os.LookupEnv(key); ok{
		return value
	}
	return fallback
}