package middleware

import (
	"context"
	"net/http"
)

type check struct{
	
}

func CheckMessage(msg any) func(http.Handler) http.Handler{
	return func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			// do some logic
			
			// create context
			ctx := context.WithValue(r.Context(), check{}, true)
			next.ServeHTTP(w, r.WithContext(ctx))
		})
	}
}
