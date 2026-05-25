package main

import (
	"log"
	"net/http"
)

func main() {
	fs := http.FileServer(http.Dir("../_build"))
	http.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) {
		fs.ServeHTTP(w, r)
	})

	log.Print("Listening on :3000...")
	err := http.ListenAndServe("127.0.0.1:3000", nil)
	if err != nil {
		log.Fatal(err)
	}
}
