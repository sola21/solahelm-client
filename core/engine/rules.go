package engine

import (
	"context"
	"fmt"
	"strconv"
	"strings"

	"github.com/metacubex/mihomo/hub/executor"
	C "github.com/sagernet/sing-box/constant"
	"github.com/sagernet/sing-box/include"
	"github.com/sagernet/sing-box/option"
	"github.com/sagernet/sing/common/json"
	"github.com/sagernet/sing/common/json/badoption"
	"go.yaml.in/yaml/v3"
)

// Rules are user rules in Clash syntax: "TYPE,PAYLOAD,TARGET[,no-resolve]".
//
// For mihomo, Replace=true swaps the profile's whole rule list, otherwise the
// lines go in front of it. sing-box rules have a different shape, so there
// the lines are translated (a common subset of types) and always go in front
// of the profile's own rules; MATCH sets route.final.
type Rules struct {
	Lines   []string `json:"lines"`
	Replace bool     `json:"replace"`
}

func (r *Rules) empty() bool { return r == nil || (len(r.Lines) == 0 && !r.Replace) }

// ParsedRule is one Clash rule line split into parts.
type ParsedRule struct {
	Type, Payload, Target string
	NoResolve             bool
}

// ParseRuleLine splits "TYPE,PAYLOAD,TARGET[,no-resolve]" (or "MATCH,TARGET").
func ParseRuleLine(line string) (ParsedRule, error) {
	parts := strings.Split(strings.TrimSpace(line), ",")
	for i := range parts {
		parts[i] = strings.TrimSpace(parts[i])
	}
	if len(parts) == 0 || parts[0] == "" {
		return ParsedRule{}, fmt.Errorf("empty rule")
	}
	r := ParsedRule{Type: strings.ToUpper(parts[0])}
	if r.Type == "MATCH" || r.Type == "FINAL" {
		if len(parts) < 2 || parts[1] == "" {
			return r, fmt.Errorf("rule %q: no target", line)
		}
		r.Type, r.Target = "MATCH", parts[1]
		return r, nil
	}
	if len(parts) < 3 || parts[1] == "" || parts[2] == "" {
		return r, fmt.Errorf("rule %q: expected TYPE,PAYLOAD,TARGET", line)
	}
	r.Payload, r.Target = parts[1], parts[2]
	for _, extra := range parts[3:] {
		if strings.EqualFold(extra, "no-resolve") {
			r.NoResolve = true
		}
	}
	return r, nil
}

// ---- mihomo ----

func injectMihomoRules(raw []byte, rules *Rules) ([]byte, error) {
	if rules.empty() {
		return raw, nil
	}
	for _, l := range rules.Lines {
		if _, err := ParseRuleLine(l); err != nil {
			return nil, err
		}
	}
	var cfg map[string]any
	if err := yaml.Unmarshal(raw, &cfg); err != nil {
		return nil, err
	}
	lines := make([]any, 0, len(rules.Lines))
	for _, l := range rules.Lines {
		lines = append(lines, strings.TrimSpace(l))
	}
	if !rules.Replace {
		existing, _ := cfg["rules"].([]any)
		lines = append(lines, existing...)
	}
	cfg["rules"] = lines
	return yaml.Marshal(cfg)
}

// MihomoProfileRules returns the rule lines and the possible targets (groups
// and proxies) of a mihomo YAML config.
func MihomoProfileRules(raw []byte) (lines []string, targets []string, err error) {
	var cfg struct {
		Rules   []string `yaml:"rules"`
		Proxies []struct {
			Name string `yaml:"name"`
		} `yaml:"proxies"`
		Groups []struct {
			Name string `yaml:"name"`
		} `yaml:"proxy-groups"`
	}
	if err := yaml.Unmarshal(raw, &cfg); err != nil {
		return nil, nil, err
	}
	for _, g := range cfg.Groups {
		targets = append(targets, g.Name)
	}
	for _, p := range cfg.Proxies {
		targets = append(targets, p.Name)
	}
	return cfg.Rules, targets, nil
}

// ---- sing-box ----

func injectSingBoxRules(o *option.Options, rules *Rules) error {
	if rules.empty() {
		return nil
	}
	tags := map[string]bool{}
	direct := ""
	for _, ob := range o.Outbounds {
		tags[ob.Tag] = true
		if ob.Type == C.TypeDirect && direct == "" {
			direct = ob.Tag
		}
	}
	for _, ep := range o.Endpoints {
		tags[ep.Tag] = true
	}
	if o.Route == nil {
		o.Route = &option.RouteOptions{}
	}
	ensureDirect := func() string {
		if direct == "" {
			direct = "solahelm-direct"
			o.Outbounds = append(o.Outbounds, option.Outbound{Type: C.TypeDirect, Tag: direct, Options: &option.DirectOutboundOptions{}})
		}
		return direct
	}

	var out []option.Rule
	for _, line := range rules.Lines {
		r, err := ParseRuleLine(line)
		if err != nil {
			return err
		}
		var action option.RuleAction
		switch strings.ToUpper(r.Target) {
		case "DIRECT":
			action.Action = C.RuleActionTypeRoute
			action.RouteOptions.Outbound = ensureDirect()
		case "REJECT", "REJECT-DROP":
			action.Action = C.RuleActionTypeReject
			action.RejectOptions.Method = C.RuleActionRejectMethodDefault
		default:
			if !tags[r.Target] {
				return fmt.Errorf("rule %q: no outbound %q in this profile", line, r.Target)
			}
			action.Action = C.RuleActionTypeRoute
			action.RouteOptions.Outbound = r.Target
		}
		if r.Type == "MATCH" {
			if action.Action == C.RuleActionTypeReject {
				return fmt.Errorf("rule %q: MATCH can't reject in sing-box", line)
			}
			o.Route.Final = action.RouteOptions.Outbound
			continue
		}
		raw, err := singBoxMatcher(r)
		if err != nil {
			return fmt.Errorf("rule %q: %w", line, err)
		}
		out = append(out, option.Rule{
			Type:           C.RuleTypeDefault,
			DefaultOptions: option.DefaultRule{RawDefaultRule: raw, RuleAction: action},
		})
	}
	// Keep sniff / hijack-dns / resolve rules first: they must run before routing decisions.
	insertAt := 0
	for i, rule := range o.Route.Rules {
		if rule.Type == C.RuleTypeDefault {
			a := rule.DefaultOptions.Action
			if a == C.RuleActionTypeSniff || a == C.RuleActionTypeHijackDNS || a == C.RuleActionTypeResolve {
				insertAt = i + 1
				continue
			}
		}
		break
	}
	rest := append([]option.Rule{}, o.Route.Rules[insertAt:]...)
	o.Route.Rules = append(append(o.Route.Rules[:insertAt], out...), rest...)
	return nil
}

// SingBoxRuleTypes are the Clash rule types that can be translated for sing-box.
var SingBoxRuleTypes = []string{
	"DOMAIN", "DOMAIN-SUFFIX", "DOMAIN-KEYWORD", "DOMAIN-REGEX", "IP-CIDR", "IP-CIDR6", "SRC-IP-CIDR",
	"DST-PORT", "SRC-PORT", "PROCESS-NAME", "PROCESS-PATH", "RULE-SET", "NETWORK", "MATCH",
}

func singBoxMatcher(r ParsedRule) (option.RawDefaultRule, error) {
	var m option.RawDefaultRule
	v := badoption.Listable[string]{r.Payload}
	switch r.Type {
	case "DOMAIN":
		m.Domain = v
	case "DOMAIN-SUFFIX":
		m.DomainSuffix = v
	case "DOMAIN-KEYWORD":
		m.DomainKeyword = v
	case "DOMAIN-REGEX":
		m.DomainRegex = v
	case "IP-CIDR", "IP-CIDR6":
		m.IPCIDR = v
	case "SRC-IP-CIDR":
		m.SourceIPCIDR = v
	case "DST-PORT", "SRC-PORT":
		p, err := strconv.ParseUint(r.Payload, 10, 16)
		if err != nil {
			return m, fmt.Errorf("bad port %q", r.Payload)
		}
		if r.Type == "DST-PORT" {
			m.Port = badoption.Listable[uint16]{uint16(p)}
		} else {
			m.SourcePort = badoption.Listable[uint16]{uint16(p)}
		}
	case "PROCESS-NAME":
		m.ProcessName = v
	case "PROCESS-PATH":
		m.ProcessPath = v
	case "RULE-SET":
		m.RuleSet = v
	case "NETWORK":
		m.Network = badoption.Listable[string]{strings.ToLower(r.Payload)}
	default:
		return m, fmt.Errorf("type %s is not supported for sing-box profiles", r.Type)
	}
	return m, nil
}

// SingBoxProfileRules describes a sing-box config's route rules as readable
// lines (read-only) and lists the outbound tags rules can point to.
func SingBoxProfileRules(raw []byte) (lines []string, targets []string, err error) {
	var cfg struct {
		Outbounds []struct {
			Type string `json:"type"`
			Tag  string `json:"tag"`
		} `json:"outbounds"`
		Route struct {
			Rules []map[string]any `json:"rules"`
			Final string           `json:"final"`
		} `json:"route"`
	}
	ctx := include.Context(context.Background())
	if err := json.UnmarshalContext(ctx, raw, &cfg); err != nil {
		return nil, nil, err
	}
	for _, ob := range cfg.Outbounds {
		switch ob.Type {
		case C.TypeSelector, C.TypeURLTest:
			targets = append([]string{ob.Tag}, targets...)
		case C.TypeDirect, C.TypeBlock, C.TypeDNS:
		default:
			targets = append(targets, ob.Tag)
		}
	}
	for _, rule := range cfg.Route.Rules {
		lines = append(lines, describeSingBoxRule(rule))
	}
	if cfg.Route.Final != "" {
		lines = append(lines, "final → "+cfg.Route.Final)
	}
	return lines, targets, nil
}

func describeSingBoxRule(rule map[string]any) string {
	action, _ := rule["action"].(string)
	target, _ := rule["outbound"].(string)
	var conds []string
	for k, v := range rule {
		if k == "action" || k == "outbound" {
			continue
		}
		conds = append(conds, fmt.Sprintf("%s=%v", k, v))
	}
	sortStrings(conds)
	cond := strings.Join(conds, " ")
	if cond == "" {
		cond = "*"
	}
	switch {
	case target != "":
		return cond + " → " + target
	case action != "":
		return cond + " → " + action
	}
	return cond
}

func sortStrings(s []string) {
	for i := 1; i < len(s); i++ {
		for j := i; j > 0 && s[j] < s[j-1]; j-- {
			s[j], s[j-1] = s[j-1], s[j]
		}
	}
}

// ---- validation ----

// Validate parses a config with the given core without starting anything.
func Validate(kind Kind, config []byte) error {
	return ValidateWithRules(kind, config, nil)
}

// ValidateWithRules is Validate after applying user rules.
func ValidateWithRules(kind Kind, config []byte, rules *Rules) error {
	switch kind {
	case SingBox:
		ctx := include.Context(context.Background())
		o, err := json.UnmarshalExtendedContext[option.Options](ctx, config)
		if err != nil {
			return err
		}
		return injectSingBoxRules(&o, rules)
	case Mihomo:
		raw, err := injectMihomoRules(config, rules)
		if err != nil {
			return err
		}
		_, err = executor.ParseWithBytes(raw)
		return err
	}
	return fmt.Errorf("unknown core %q", kind)
}
