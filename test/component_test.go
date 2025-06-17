package test

import (
	"fmt"
	"testing"

	"github.com/cloudposse/test-helpers/pkg/atmos"
	helper "github.com/cloudposse/test-helpers/pkg/atmos/component-helper"
	"github.com/gruntwork-io/terratest/modules/aws"
	"github.com/stretchr/testify/assert"
)

type ComponentSuite struct {
	helper.TestSuite
}

type KmsKey struct {
	AliasArn  string `json:"alias_arn"`
	AliasName string `json:"alias_name"`
	KeyArn    string `json:"key_arn"`
	KeyId     string `json:"key_id"`
}

func (s *ComponentSuite) TestBasic() {
	const component = "aws-kms/basic"
	const stack = "default-test"
	const awsRegion = "us-east-2"

	defer s.DestroyAtmosComponent(s.T(), component, stack, nil)
	options, _ := s.DeployAtmosComponent(s.T(), component, stack, nil)
	assert.NotNil(s.T(), options)

	accountID := aws.GetAccountId(s.T())

	var key KmsKey
	atmos.OutputStruct(s.T(), options, "kms_key", &key)

	assert.Contains(s.T(), key.KeyArn, fmt.Sprintf("arn:aws:kms:%s:%s:key/", awsRegion, accountID))
	assert.Contains(s.T(), key.AliasArn, fmt.Sprintf("arn:aws:kms:%s:%s:alias/", awsRegion, accountID))
	assert.Equal(s.T(), "alias/test", key.AliasName)
	assert.Regexp(s.T(), `^[0-9a-fA-F\-]{36}$`, key.KeyId)

	s.DriftTest(component, stack, nil)
}

func (s *ComponentSuite) TestEnabledFlag() {
	const component = "aws-kms/disabled"
	const stack = "default-test"
	s.VerifyEnabledFlag(component, stack, nil)
}

func TestRunSuite(t *testing.T) {
	suite := new(ComponentSuite)
	helper.Run(t, suite)
}
