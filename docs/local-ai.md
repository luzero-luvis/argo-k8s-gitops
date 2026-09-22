# Local AI: Ollama + Qwen3

The `ollama-qwen` Argo CD application deploys a single CPU-first Ollama
StatefulSet in the `ai` namespace. Its init container pulls `qwen3:1.7b` before
the main container becomes ready. Models are retained on the 10Gi Longhorn PVC
named `ollama-models`.

The Ollama Service is not directly exposed outside the cluster. The existing
`agentgateway` Gateway terminates TLS for `ai.example.com` and its
`AgentgatewayBackend` forwards OpenAI-compatible chat-completion requests to
`ollama.ai.svc.cluster.local:11434`. cert-manager obtains and renews the
certificate through Let's Encrypt DNS-01 with DigitalOcean.

## Test it

After both Argo CD applications are healthy, send a request through
agentgateway:

```bash
curl https://ai.example.com/v1/chat/completions \
  -H 'content-type: application/json' \
  -d '{
    "model": "qwen3:1.7b",
    "messages": [{"role": "user", "content": "Say hello in one short sentence."}]
  }'
```

The gateway pins requests to `qwen3:1.7b`; no provider API key is required.
The existing Gateway has a LoadBalancer Service, so add an authentication policy
before allowing untrusted clients to reach this path.
