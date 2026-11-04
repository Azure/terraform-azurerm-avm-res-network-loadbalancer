// This test is compiled INSIDE the unmodified pinned AzAPI source tree by
// Test-BackendMemberWrite.ps1. It exercises provider methods and the real ARM
// HTTP serializer using a recording in-memory transport, never an Azure host.
package services

import (
	"context"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"reflect"
	"strings"
	"testing"
	"time"

	"github.com/Azure/azure-sdk-for-go/sdk/azcore"
	"github.com/Azure/azure-sdk-for-go/sdk/azcore/arm"
	"github.com/Azure/azure-sdk-for-go/sdk/azcore/cloud"
	"github.com/Azure/azure-sdk-for-go/sdk/azcore/policy"
	"github.com/Azure/terraform-provider-azapi/internal/clients"
	"github.com/Azure/terraform-provider-azapi/internal/features"
	"github.com/Azure/terraform-provider-azapi/internal/services/dynamic"
	"github.com/Azure/terraform-provider-azapi/utils"
	fwaction "github.com/hashicorp/terraform-plugin-framework/action"
	"github.com/hashicorp/terraform-plugin-framework/diag"
	fwresource "github.com/hashicorp/terraform-plugin-framework/resource"
	"github.com/hashicorp/terraform-plugin-framework/tfsdk"
	"github.com/hashicorp/terraform-plugin-go/tftypes"
)

const memberPoolID = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/offline/providers/Microsoft.Network/loadBalancers/lb/backendAddressPools/pool"
const memberPoolType = "Microsoft.Network/loadBalancers/backendAddressPools@2025-01-01"

type memberCredential struct{}

func (memberCredential) GetToken(context.Context, policy.TokenRequestOptions) (azcore.AccessToken, error) {
	return azcore.AccessToken{Token: "offline-not-a-credential", ExpiresOn: time.Now().Add(time.Hour)}, nil
}

// Only our expected synthetic endpoint is accepted. There is no network
// fallback, Azure CLI authentication, actual token acquisition or logging.
type memberTransport struct {
	live   map[string]interface{}
	writes []map[string]interface{}
}

func memberClone(v interface{}) interface{} {
	b, _ := json.Marshal(v)
	var out interface{}
	_ = json.Unmarshal(b, &out)
	return out
}

func (m *memberTransport) Do(req *http.Request) (*http.Response, error) {
	if req.URL.Host != "member-boundary.invalid" || req.URL.Path != memberPoolID || req.URL.Query().Get("api-version") != "2025-01-01" {
		return nil, fmt.Errorf("unexpected offline endpoint: %s %s", req.Method, req.URL.Redacted())
	}
	switch req.Method {
	case http.MethodGet:
	case http.MethodPut:
		var b map[string]interface{}
		if err := json.NewDecoder(req.Body).Decode(&b); err != nil {
			return nil, err
		}
		m.writes = append(m.writes, memberClone(b).(map[string]interface{}))
		// This is an HTTP sink, NOT an Azure service emulator or persistence
		// proof. Return the submitted collection plus synthetic read-only /
		// server-added fields to exercise provider shaping and the NEXT write.
		m.live = memberClone(b).(map[string]interface{})
	default:
		return nil, fmt.Errorf("unexpected method %s", req.Method)
	}
	out := memberClone(m.live).(map[string]interface{})
	out["id"] = memberPoolID
	out["name"] = "pool"
	out["etag"] = "server-etag"
	p := out["properties"].(map[string]interface{})
	p["provisioningState"] = "Succeeded"
	for _, v := range p["loadBalancerBackendAddresses"].([]interface{}) {
		a := v.(map[string]interface{})
		a["id"] = memberPoolID + "/backendAddresses/" + a["name"].(string)
		ap := a["properties"].(map[string]interface{})
		ap["inboundNatRulesPortMapping"] = []interface{}{}
		if f, ok := ap["loadBalancerFrontendIPConfiguration"].(map[string]interface{}); ok {
			// A different synthesized IP for each frontend makes accidental
			// positional carry-forward observable on same-count retargets.
			if strings.Contains(f["id"].(string), "/west/") {
				ap["ipAddress"] = "192.0.2.22"
			} else {
				ap["ipAddress"] = "192.0.2.11"
			}
		}
	}
	b, _ := json.Marshal(out)
	return &http.Response{StatusCode: 200, Request: req, Header: http.Header{"Content-Type": {"application/json"}}, Body: io.NopCloser(strings.NewReader(string(b)))}, nil
}

func memberRaw(t *testing.T, typ tftypes.Type, body interface{}) tftypes.Value {
	t.Helper()
	ot := typ.(tftypes.Object)
	values := make(map[string]tftypes.Value)
	for k, v := range ot.AttributeTypes {
		values[k] = tftypes.NewValue(v, nil)
	}
	values["type"] = tftypes.NewValue(tftypes.String, memberPoolType)
	values["resource_id"] = tftypes.NewValue(tftypes.String, memberPoolID)
	b, _ := json.Marshal(body)
	d, err := dynamic.FromJSONImplied(b)
	if err != nil {
		t.Fatal(err)
	}
	tv, err := d.ToTerraformValue(context.Background())
	if err != nil {
		t.Fatal(err)
	}
	values["body"] = tv
	if _, ok := values["method"]; ok {
		values["method"] = tftypes.NewValue(tftypes.String, "PUT")
	}
	if _, ok := values["ignore_missing_property"]; ok {
		values["ignore_missing_property"] = tftypes.NewValue(tftypes.Bool, false)
		values["ignore_casing"] = tftypes.NewValue(tftypes.Bool, false)
	}
	return tftypes.NewValue(typ, values)
}

type memberPrivate struct{}

func (memberPrivate) GetKey(context.Context, string) ([]byte, diag.Diagnostics) { return nil, nil }
func (memberPrivate) SetKey(context.Context, string, []byte) diag.Diagnostics  { return nil }

func memberItems(body map[string]interface{}) []interface{} {
	return body["properties"].(map[string]interface{})["loadBalancerBackendAddresses"].([]interface{})
}

func memberBody(items []interface{}, metadata bool) map[string]interface{} {
	p := map[string]interface{}{"loadBalancerBackendAddresses": items}
	if metadata {
		p["virtualNetwork"] = nil
		p["tunnelInterfaces"] = []interface{}{}
	}
	return map[string]interface{}{"properties": p}
}

func memberAddress(mode, name, target string, vnet bool) interface{} {
	p := map[string]interface{}{}
	if mode == "IP" {
		p["ipAddress"] = target
		if vnet {
			p["virtualNetwork"] = map[string]interface{}{"id": "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/offline/providers/Microsoft.Network/virtualNetworks/vnet"}
		}
	} else {
		p["loadBalancerFrontendIPConfiguration"] = map[string]interface{}{"id": "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/offline/providers/Microsoft.Network/loadBalancers/" + target + "/frontendIPConfigurations/public"}
	}
	return map[string]interface{}{"name": name, "properties": p}
}

func TestAVMMemberWritePinnedMergeRegression(t *testing.T) {
	old := memberBody([]interface{}{memberAddress("Frontend", "east", "east", false), memberAddress("Frontend", "west", "west", false)}, true)
	desired := memberBody([]interface{}{memberAddress("Frontend", "east", "east", false)}, false)
	merged := utils.MergeObjectWithOption(old, desired, utils.UpdateJsonOption{}).(map[string]interface{})
	if len(memberItems(merged)) != 2 {
		t.Fatal("negative control must reproduce the pinned named-array append defect")
	}
	old = memberBody([]interface{}{memberAddress("Frontend", "old", "west", false)}, false)
	memberItems(old)[0].(map[string]interface{})["properties"].(map[string]interface{})["ipAddress"] = "192.0.2.22"
	desired = memberBody([]interface{}{memberAddress("Frontend", "new", "east", false)}, false)
	fallback := utils.MergeObjectWithOption(old, desired, utils.UpdateJsonOption{ListUniqueIdProperty: map[string]string{"properties.loadBalancerBackendAddresses": "id"}}).(map[string]interface{})
	if memberItems(fallback)[0].(map[string]interface{})["properties"].(map[string]interface{})["ipAddress"] != "192.0.2.22" {
		t.Fatal("negative control must expose same-length positional synthesized-IP carry-forward")
	}
}

func TestAVMMemberWriteActionUpdaterBoundary(t *testing.T) {
	for _, mode := range []string{"IP", "Frontend"} {
		t.Run(mode, func(t *testing.T) {
			ctx := context.Background()
			a, b := "10.0.0.10", "10.0.0.11"
			if mode == "Frontend" {
				a, b = "east", "west"
			}
			one := memberAddress(mode, "east", a, mode == "IP")
			two := memberAddress(mode, "west", b, mode == "IP")
			transport := &memberTransport{live: memberBody([]interface{}{one, two}, true)}
			rc, err := clients.NewResourceClient(memberCredential{}, &arm.ClientOptions{
				ClientOptions: policy.ClientOptions{Transport: transport, Cloud: cloud.Configuration{Services: map[cloud.ServiceName]cloud.ServiceConfiguration{cloud.ResourceManager: {Endpoint: "https://member-boundary.invalid", Audience: "https://member-boundary.invalid"}}}},
				DisableRPRegistration: true,
			})
			if err != nil {
				t.Fatal(err)
			}
			client := &clients.Client{ResourceClient: rc, Features: features.UserFeatures{DisableDefaultOutput: true}}
			action := AzapiResourceAction{ProviderData: client}
			updater := AzapiUpdateResource{ProviderData: client}
			var as fwaction.SchemaResponse
			action.Schema(ctx, fwaction.SchemaRequest{}, &as)
			var rs fwresource.SchemaResponse
			updater.Schema(ctx, fwresource.SchemaRequest{}, &rs)
			atype := as.Schema.Type().TerraformType(ctx)
			rtype := rs.Schema.Type().TerraformType(ctx)
			state := tfsdk.State{Schema: rs.Schema, Raw: tftypes.NewValue(rtype, nil)}
			cases := []struct {
				name  string
				items []interface{}
			}{
				{"two_to_one", []interface{}{one}},
				{"one_to_zero", []interface{}{}},
				{"restore_two", []interface{}{one, two}},
				{"same_count_rename", []interface{}{memberAddress(mode, "renamed", a, mode == "IP"), two}},
				{"same_count_retarget_and_omit_vnet", []interface{}{memberAddress(mode, "renamed", b, false), memberAddress(mode, "west", a, false)}},
				{"same_count_reorder", []interface{}{two, one}},
				{"explicit_null_vnet", []interface{}{memberAddress(mode, "east", a, false), two}},
			}
			for _, c := range cases {
				t.Run(c.name, func(t *testing.T) {
					if c.name == "explicit_null_vnet" {
						c.items[0].(map[string]interface{})["properties"].(map[string]interface{})["virtualNetwork"] = nil
					}
					exact := memberBody(c.items, true)
					configured := memberBody(c.items, false)
					start := len(transport.writes)
					var ar fwaction.InvokeResponse
					action.Invoke(ctx, fwaction.InvokeRequest{Config: tfsdk.Config{Schema: as.Schema, Raw: memberRaw(t, atype, exact)}}, &ar)
					if ar.Diagnostics.HasError() {
						t.Fatalf("action diagnostics: %v", ar.Diagnostics)
					}
					if !reflect.DeepEqual(transport.writes[start], exact) {
						t.Fatalf("actual action HTTP body was not EXACT: %#v", transport.writes[start])
					}
					raw := memberRaw(t, rtype, configured)
					cfg := tfsdk.Config{Schema: rs.Schema, Raw: raw}
					plan := tfsdk.Plan{Schema: rs.Schema, Raw: raw}
					var ds diag.Diagnostics
					updater.CreateUpdate(ctx, cfg, plan, &state, &ds, memberPrivate{})
					if ds.HasError() {
						t.Fatalf("updater diagnostics: %v", ds)
					}
					if len(transport.writes) != start+2 {
						t.Fatalf("expected one exact PUT and one updater PUT, got %d", len(transport.writes)-start)
					}
					up := transport.writes[start+1]["properties"].(map[string]interface{})
					metadata := exact["properties"].(map[string]interface{})
					if !reflect.DeepEqual(up["virtualNetwork"], metadata["virtualNetwork"]) || !reflect.DeepEqual(up["tunnelInterfaces"], metadata["tunnelInterfaces"]) {
						t.Fatalf("updater replay lost configured metadata: %#v", up)
					}
					actual := memberItems(transport.writes[start+1])
					if len(actual) != len(c.items) {
						t.Fatalf("updater replay appended removed members: %#v", actual)
					}
					for i, v := range actual {
						item := v.(map[string]interface{})
						desired := c.items[i].(map[string]interface{})
						if item["name"] != desired["name"] {
							t.Fatalf("stale member/name in updater PUT: %#v", actual)
						}
						props := item["properties"].(map[string]interface{})
						want := desired["properties"].(map[string]interface{})
						for k, value := range want {
							if !reflect.DeepEqual(props[k], value) {
								t.Fatalf("stale configured property %s: got %#v want %#v", k, props[k], value)
							}
						}
						if _, exists := want["virtualNetwork"]; !exists && props["virtualNetwork"] != nil {
							t.Fatalf("omitted VNet replayed into member: %#v", props)
						}
						if mode == "Frontend" {
							expectedIP := "192.0.2.11"
							if strings.Contains(want["loadBalancerFrontendIPConfiguration"].(map[string]interface{})["id"].(string), "/west/") {
								expectedIP = "192.0.2.22"
							}
							if props["ipAddress"] != expectedIP {
								t.Fatalf("stale synthesized IP replayed on frontend retarget: %#v", props)
							}
						}
					}
					// Real provider Read shaping must converge twice with
					// server-added fields, without hiding member-list drift.
					for n := 0; n < 2; n++ {
						var rr fwresource.ReadResponse
						rr.State = state
						updater.Read(ctx, fwresource.ReadRequest{State: state}, &rr)
						if rr.Diagnostics.HasError() {
							t.Fatalf("read diagnostics: %v", rr.Diagnostics)
						}
						state = rr.State
						var model AzapiUpdateResourceModel
						if ds := state.Get(ctx, &model); ds.HasError() {
							t.Fatal(ds)
						}
						var wanted AzapiUpdateResourceModel
						if ds := cfg.Get(ctx, &wanted); ds.HasError() {
							t.Fatal(ds)
						}
						if !dynamic.SemanticallyEqual(model.Body, wanted.Body) {
							t.Fatalf("fresh read %d did not converge: got %s want %s", n, model.Body, wanted.Body)
						}
					}
				})
			}
			// An out-of-band added entry is still visible to the REAL reader.
			transport.live["properties"].(map[string]interface{})["loadBalancerBackendAddresses"] = append(memberItems(transport.live), memberAddress(mode, "rogue", b, false))
			var rr fwresource.ReadResponse
			rr.State = state
			updater.Read(ctx, fwresource.ReadRequest{State: state}, &rr)
			if rr.Diagnostics.HasError() {
				t.Fatal(rr.Diagnostics)
			}
			var drift AzapiUpdateResourceModel
			rr.State.Get(ctx, &drift)
			var prior AzapiUpdateResourceModel
			state.Get(ctx, &prior)
			if dynamic.SemanticallyEqual(drift.Body, prior.Body) {
				t.Fatal("external list drift was hidden")
			}
			writes := len(transport.writes)
			var deleted fwresource.DeleteResponse
			updater.Delete(ctx, fwresource.DeleteRequest{State: state}, &deleted)
			if deleted.Diagnostics.HasError() || len(transport.writes) != writes {
				t.Fatal("retiring the partial binding must not issue an Azure request or delete the pool")
			}
			t.Log("real action Invoke + ARM HTTP serialization + updater CreateUpdate/Read: exact mutations, two shaped refreshes and visible added-member drift")
		})
	}
}
