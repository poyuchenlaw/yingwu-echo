package main

import (
	"log"
	"os"

	"github.com/gin-gonic/gin"
	// TODO: wire internal packages once scaffolding is complete
	// "github.com/simonchen/yingwu-echo/backend/internal/api"
)

func main() {
	port := os.Getenv("PORT")
	if port == "" {
		port = "8080"
	}

	r := gin.Default()

	// Health check
	r.GET("/health", func(c *gin.Context) {
		c.JSON(200, gin.H{"status": "ok", "service": "yingwu-echo"})
	})

	// TODO: register route groups
	// api.RegisterRoutes(r)

	log.Printf("yingwu-echo server starting on :%s", port)
	if err := r.Run(":" + port); err != nil {
		log.Fatalf("server failed: %v", err)
	}
}
