package config

// Config models the user configuration file (by default: $HOME/.config/free-ddns/config.yaml).
//
// The struct is intended to be used with a YAML unmarshaller (e.g. gopkg.in/yaml.v3)
// so the `yaml` tags must match the YAML keys.
type Config struct {
	DomainNames      []string   `yaml:"domainNames" json:"domainNames"`
	IPAddressVersion string     `yaml:"ipAddressVersion" json:"ipAddressVersion"`
	DNSProvider      string     `yaml:"dnsProvider" json:"dnsProvider"`
	Credential       Credential `yaml:"credential" json:"credential"`
}

type Credential struct {
	Tencent    TencentCredential    `yaml:"tencent" json:"tencent"`
	Aliyun     AliyunCredential     `yaml:"aliyun" json:"aliyun"`
	Cloudflare CloudflareCredential `yaml:"cloudflare" json:"cloudflare"`
}

type TencentCredential struct {
	SecretID  string `yaml:"secretId" json:"secretId"`
	SecretKey string `yaml:"secretKey" json:"secretKey"`
}

type AliyunCredential struct {
	AccessKeyID     string `yaml:"accessKeyId" json:"accessKeyId"`
	AccessKeySecret string `yaml:"accessKeySecret" json:"accessKeySecret"`
}

type CloudflareCredential struct {
	Token string `yaml:"token" json:"token"`
}
