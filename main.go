package main

import (
	"encoding/json"
	"fmt"
	"log"
	"net/http"
	"os"
	"path/filepath"

	admissionv1 "k8s.io/api/admission/v1"
	corev1 "k8s.io/api/core/v1"
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
)

const (
	tlsKeyName  = "tls.key"
	tlsCertName = "tls.crt"
)

func main() {
	mux := http.NewServeMux()
	mux.HandleFunc("/validate", validate)
	if certDir := os.Getenv("CERT_DIR"); certDir != "" {
		certFile := filepath.Join(certDir, tlsCertName)
		keyFile := filepath.Join(certDir, tlsKeyName)
		log.Fatal(http.ListenAndServeTLS(":8000", certFile, keyFile, mux))
	} else {
		log.Fatal(http.ListenAndServe(":8000", mux))
	}
}

func validate(w http.ResponseWriter, r *http.Request) {
	var (
		reviewReq, reviewResp admissionv1.AdmissionReview
		pd                    corev1.Pod
	)

	dec := json.NewDecoder(r.Body)
	if err := dec.Decode(&reviewReq); err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}

	// Get pod object from request
	if err := json.Unmarshal(reviewReq.Request.Object.Raw, &pd); err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}
	log.Println("validating pod", pd.Name)

	reviewResp.TypeMeta = reviewReq.TypeMeta
	reviewResp.Response = &admissionv1.AdmissionResponse{
		UID:     reviewReq.Request.UID, // write the unique identifier back
		Allowed: true,
		Result:  nil,
	}

	for _, ctr := range pd.Spec.Containers {
		if len(ctr.Env) > 0 {
			reviewResp.Response.Allowed = false
			reviewResp.Response.Result = &metav1.Status{
				Status:  "Failure",
				Message: fmt.Sprintf("%s is using env vars", ctr.Name),
				Reason:  metav1.StatusReason(fmt.Sprintf("%s is using env vars", ctr.Name)),
				Code:    402,
			}
			break
		}
	}

	js, err := json.Marshal(reviewResp)
	if err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}
	w.Header().Set("Content-Type", "application/json")
	w.Write(js)
}
