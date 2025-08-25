// Package ipservice provides IP geolocation services with multiple providers
package ipservice

import (
	"encoding/json"
	"fmt"
	"net/http"
	"os"
	"strings"
	"time"

	"github.com/Krea-University/speed-test-server/internal/types"
)

// Provider interface defines methods that IP geolocation providers must implement
type Provider interface {
	GetIPInfo(ip string) (*types.IPResponse, error)
	Name() string
}

// Service manages multiple IP geolocation providers with fallback support
type Service struct {
	providers []Provider
	client    *http.Client
}

// NewService creates a new IP service with configured providers
func NewService() *Service {
	client := &http.Client{
		Timeout: 5 * time.Second,
	}

	service := &Service{
		client: client,
	}

	// Add providers in order of preference
	service.providers = []Provider{
		NewIPInfoProvider(client),
		NewIPAPIProvider(client),
		NewFreeGeoIPProvider(client),
	}

	return service
}

// GetIPInfo attempts to get IP information using providers in order until one succeeds
func (s *Service) GetIPInfo(ip string) (*types.IPResponse, error) {
	var lastErr error

	for _, provider := range s.providers {
		result, err := provider.GetIPInfo(ip)
		if err == nil {
			result.Source = provider.Name()
			return result, nil
		}
		lastErr = err
	}

	return &types.IPResponse{IP: ip}, fmt.Errorf("all providers failed, last error: %v", lastErr)
}

// IPInfoProvider implements the ipinfo.io API
type IPInfoProvider struct {
	client *http.Client
	token  string
}

// IPInfoResponse represents the response from ipinfo.io API
type IPInfoResponse struct {
	IP       string `json:"ip"`
	City     string `json:"city"`
	Region   string `json:"region"`
	Country  string `json:"country"`
	Loc      string `json:"loc"`
	Org      string `json:"org"`
	Postal   string `json:"postal"`
	Timezone string `json:"timezone"`
}

// NewIPInfoProvider creates a new ipinfo.io provider
func NewIPInfoProvider(client *http.Client) *IPInfoProvider {
	token := os.Getenv("IPINFO_TOKEN")
	if token == "" {
		token = "20e16b08cd509a" // Fallback token
	}

	return &IPInfoProvider{
		client: client,
		token:  token,
	}
}

// Name returns the provider name
func (p *IPInfoProvider) Name() string {
	return "ipinfo.io"
}

// GetIPInfo fetches IP information from ipinfo.io
func (p *IPInfoProvider) GetIPInfo(ip string) (*types.IPResponse, error) {
	url := fmt.Sprintf("https://ipinfo.io/%s?token=%s", ip, p.token)

	resp, err := p.client.Get(url)
	if err != nil {
		return nil, fmt.Errorf("ipinfo request failed: %v", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("ipinfo returned status %d", resp.StatusCode)
	}

	var ipInfo IPInfoResponse
	if err := json.NewDecoder(resp.Body).Decode(&ipInfo); err != nil {
		return nil, fmt.Errorf("failed to decode ipinfo response: %v", err)
	}

	result := &types.IPResponse{
		IP:       ipInfo.IP,
		City:     ipInfo.City,
		Region:   ipInfo.Region,
		Country:  ipInfo.Country,
		Location: ipInfo.Loc,
		Postal:   ipInfo.Postal,
		Timezone: ipInfo.Timezone,
		ISP:      ipInfo.Org,
	}

	// Extract ASN from org field if available
	if strings.Contains(ipInfo.Org, "AS") {
		result.ASN = ipInfo.Org
	}

	return result, nil
}

// IPAPIProvider implements the ip-api.com API (free, no key required)
type IPAPIProvider struct {
	client *http.Client
}

// IPAPIResponse represents the response from ip-api.com
type IPAPIResponse struct {
	Status      string  `json:"status"`
	Country     string  `json:"country"`
	CountryCode string  `json:"countryCode"`
	Region      string  `json:"region"`
	RegionName  string  `json:"regionName"`
	City        string  `json:"city"`
	Zip         string  `json:"zip"`
	Lat         float64 `json:"lat"`
	Lon         float64 `json:"lon"`
	Timezone    string  `json:"timezone"`
	ISP         string  `json:"isp"`
	Org         string  `json:"org"`
	AS          string  `json:"as"`
	Query       string  `json:"query"`
}

// NewIPAPIProvider creates a new ip-api.com provider
func NewIPAPIProvider(client *http.Client) *IPAPIProvider {
	return &IPAPIProvider{client: client}
}

// Name returns the provider name
func (p *IPAPIProvider) Name() string {
	return "ip-api.com"
}

// GetIPInfo fetches IP information from ip-api.com
func (p *IPAPIProvider) GetIPInfo(ip string) (*types.IPResponse, error) {
	url := fmt.Sprintf("http://ip-api.com/json/%s", ip)

	resp, err := p.client.Get(url)
	if err != nil {
		return nil, fmt.Errorf("ip-api request failed: %v", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("ip-api returned status %d", resp.StatusCode)
	}

	var apiResp IPAPIResponse
	if err := json.NewDecoder(resp.Body).Decode(&apiResp); err != nil {
		return nil, fmt.Errorf("failed to decode ip-api response: %v", err)
	}

	if apiResp.Status == "fail" {
		return nil, fmt.Errorf("ip-api returned failure status")
	}

	location := ""
	if apiResp.Lat != 0 && apiResp.Lon != 0 {
		location = fmt.Sprintf("%.4f,%.4f", apiResp.Lat, apiResp.Lon)
	}

	return &types.IPResponse{
		IP:       apiResp.Query,
		City:     apiResp.City,
		Region:   apiResp.RegionName,
		Country:  apiResp.CountryCode,
		Location: location,
		Postal:   apiResp.Zip,
		Timezone: apiResp.Timezone,
		ISP:      apiResp.ISP,
		ASN:      apiResp.AS,
	}, nil
}

// FreeGeoIPProvider implements a basic free GeoIP service
type FreeGeoIPProvider struct {
	client *http.Client
}

// FreeGeoIPResponse represents a basic GeoIP response
type FreeGeoIPResponse struct {
	IP          string  `json:"ip"`
	CountryCode string  `json:"country_code"`
	CountryName string  `json:"country_name"`
	RegionCode  string  `json:"region_code"`
	RegionName  string  `json:"region_name"`
	City        string  `json:"city"`
	ZipCode     string  `json:"zip_code"`
	TimeZone    string  `json:"time_zone"`
	Latitude    float64 `json:"latitude"`
	Longitude   float64 `json:"longitude"`
}

// NewFreeGeoIPProvider creates a new basic GeoIP provider
func NewFreeGeoIPProvider(client *http.Client) *FreeGeoIPProvider {
	return &FreeGeoIPProvider{client: client}
}

// Name returns the provider name
func (p *FreeGeoIPProvider) Name() string {
	return "freeipapi.com"
}

// GetIPInfo fetches IP information from a free GeoIP service
func (p *FreeGeoIPProvider) GetIPInfo(ip string) (*types.IPResponse, error) {
	url := fmt.Sprintf("https://freeipapi.com/api/json/%s", ip)

	resp, err := p.client.Get(url)
	if err != nil {
		return nil, fmt.Errorf("freeipapi request failed: %v", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("freeipapi returned status %d", resp.StatusCode)
	}

	var geoResp FreeGeoIPResponse
	if err := json.NewDecoder(resp.Body).Decode(&geoResp); err != nil {
		return nil, fmt.Errorf("failed to decode freeipapi response: %v", err)
	}

	location := ""
	if geoResp.Latitude != 0 && geoResp.Longitude != 0 {
		location = fmt.Sprintf("%.4f,%.4f", geoResp.Latitude, geoResp.Longitude)
	}

	return &types.IPResponse{
		IP:       geoResp.IP,
		City:     geoResp.City,
		Region:   geoResp.RegionName,
		Country:  geoResp.CountryCode,
		Location: location,
		Postal:   geoResp.ZipCode,
		Timezone: geoResp.TimeZone,
	}, nil
}
