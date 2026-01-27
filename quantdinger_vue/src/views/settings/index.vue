<template>
  <div class="settings-page" :class="{ 'theme-dark': isDarkTheme }">
    <!-- 重启提示 -->
    <a-alert
      v-if="showRestartTip"
      class="restart-alert"
      type="warning"
      showIcon
      closable
      @close="showRestartTip = false"
    >
      <template slot="message">
        <span>{{ $t('settings.restartRequired') }}</span>
        <a-button size="small" type="link" @click="copyRestartCommand">
          {{ $t('settings.copyRestartCmd') }}
        </a-button>
      </template>
    </a-alert>

    <div class="settings-header">
      <h2 class="page-title">
        <a-icon type="setting" />
        <span>{{ $t('settings.title') }}</span>
      </h2>
      <p class="page-desc">{{ $t('settings.description') }}</p>
    </div>

    <a-spin :spinning="loading">
      <div class="settings-content">
        <a-collapse v-model="activeKeys" :bordered="false" class="settings-collapse">
          <a-collapse-panel v-for="(group, groupKey) in sortedSchema" :key="groupKey">
            <template slot="header">
              <span class="panel-header">
                <a-icon :type="group.icon || getGroupIcon(groupKey)" class="panel-icon-left" />
                <span class="panel-title">{{ getGroupTitle(groupKey, group.title) }}</span>
              </span>
            </template>

            <!-- AI 组特殊：显示 OpenRouter 余额查询卡片 -->
            <div v-if="groupKey === 'ai'" class="openrouter-balance-card">
              <a-card size="small" :bordered="false">
                <div class="balance-header">
                  <span class="balance-title">
                    <a-icon type="wallet" style="margin-right: 6px;" />
                    {{ tOr('settings.openrouterBalance', 'OpenRouter 账户余额') }}
                  </span>
                  <a-button size="small" type="primary" ghost :loading="balanceLoading" @click="queryOpenRouterBalance">
                    <a-icon type="sync" />
                    {{ tOr('settings.queryBalance', '查询余额') }}
                  </a-button>
                </div>
                <div v-if="openrouterBalance" class="balance-info">
                  <a-row :gutter="16">
                    <a-col :span="8">
                      <a-statistic
                        :title="tOr('settings.balanceUsage', '已使用')"
                        :value="openrouterBalance.usage"
                        prefix="$"
                        :precision="4"
                        :value-style="{ color: '#cf1322' }"
                      />
                    </a-col>
                    <a-col :span="8">
                      <a-statistic
                        :title="tOr('settings.balanceRemaining', '剩余额度')"
                        :value="openrouterBalance.limit_remaining !== null ? openrouterBalance.limit_remaining : '∞'"
                        :prefix="openrouterBalance.limit_remaining !== null ? '$' : ''"
                        :precision="openrouterBalance.limit_remaining !== null ? 4 : 0"
                        :value-style="{ color: openrouterBalance.limit_remaining !== null && openrouterBalance.limit_remaining < 1 ? '#cf1322' : '#3f8600' }"
                      />
                    </a-col>
                    <a-col :span="8">
                      <a-statistic
                        :title="tOr('settings.balanceLimit', '总限额')"
                        :value="openrouterBalance.limit !== null ? openrouterBalance.limit : '∞'"
                        :prefix="openrouterBalance.limit !== null ? '$' : ''"
                        :precision="openrouterBalance.limit !== null ? 2 : 0"
                      />
                    </a-col>
                  </a-row>
                  <div v-if="openrouterBalance.is_free_tier" class="free-tier-badge">
                    <a-tag color="blue">{{ tOr('settings.freeTier', '免费额度') }}</a-tag>
                  </div>
                </div>
                <div v-else class="balance-empty">
                  <a-icon type="info-circle" style="margin-right: 6px;" />
                  {{ tOr('settings.balanceNotQueried', '点击“查询余额”获取账户信息') }}
                </div>
              </a-card>
            </div>

            <a-form :form="form" layout="vertical" class="settings-form">
              <a-row :gutter="24">
                <a-col
                  :xs="24"
                  :sm="24"
                  :md="12"
                  :lg="12"
                  v-for="item in group.items"
                  :key="item.key">
                  <a-form-item>
                    <template slot="label">
                      <span class="form-label-with-tooltip">
                        <span class="label-text">{{ getItemLabel(groupKey, item) }}</span>
                        <a-tooltip v-if="item.description" placement="top">
                          <template slot="title">
                            {{ getItemDescription(groupKey, item) }}
                          </template>
                          <a-icon type="question-circle" class="help-icon" />
                        </a-tooltip>
                        <a
                          v-if="item.link"
                          :href="item.link"
                          target="_blank"
                          rel="noopener noreferrer"
                          class="api-link"
                          @click.stop
                        >
                          <a-icon type="link" />
                          {{ getLinkText(item.link_text) }}
                        </a>
                      </span>
                    </template>
                    <!-- 文本输入 -->
                    <template v-if="item.type === 'text'">
                      <div v-if="item.key === 'AI_MODELS_JSON'">
                        <a-textarea
                          v-decorator="[item.key, { initialValue: getFieldValue(groupKey, item.key) }]"
                          :auto-size="{ minRows: 3, maxRows: 10 }"
                          :placeholder="item.default ? `${$t('settings.default')}: ${item.default}` : ''"
                        />
                      </div>
                      <div v-else-if="isAiProviderModelKey(item.key)" style="display:flex; gap: 8px; align-items: center;">
                        <!-- Hidden field keeps schema-driven save payload string-compatible -->
                        <a-input v-show="false" v-decorator="[item.key, { initialValue: getFieldValue(groupKey, item.key) }]" />
                        <a-select
                          mode="multiple"
                          show-search
                          :value="providerModelSelections[item.key] || []"
                          style="flex: 1"
                          :placeholder="tOr('settings.selectModels', '选择模型（可多选）')"
                          :filter-option="filterModelOption"
                          :maxTagCount="2"
                          @change="onProviderModelChange(item.key, $event)"
                        >
                          <a-select-option v-for="(label, id) in getProviderModelsMap(item.key)" :key="id" :value="id">
                            {{ label }}
                          </a-select-option>
                        </a-select>
                        <a-button
                          size="small"
                          type="primary"
                          ghost
                          icon="sync"
                          :loading="isProviderLoading(item.key)"
                          @click="fetchModelsForKey(item.key)"
                        >
                          {{ tOr('settings.fetchModels', '拉取') }}
                        </a-button>
                      </div>
                      <a-input
                        v-else
                        v-decorator="[item.key, { initialValue: getFieldValue(groupKey, item.key) }]"
                        :placeholder="item.default ? `${$t('settings.default')}: ${item.default}` : ''"
                        allowClear
                      />
                    </template>

                    <!-- 密码输入 -->
                    <template v-else-if="item.type === 'password'">
                      <div class="password-field">
                        <a-input
                          v-decorator="[item.key, { initialValue: getFieldValue(groupKey, item.key) }]"
                          :type="passwordVisible[item.key] ? 'text' : 'password'"
                          :placeholder="$t('settings.inputApiKey')"
                          allowClear
                        >
                          <a-icon
                            slot="suffix"
                            :type="passwordVisible[item.key] ? 'eye' : 'eye-invisible'"
                            @click="togglePasswordVisible(item.key)"
                            style="cursor: pointer"
                          />
                        </a-input>
                      </div>
                    </template>

                    <!-- 数字输入 -->
                    <template v-else-if="item.type === 'number'">
                      <a-input-number
                        v-decorator="[item.key, { initialValue: getNumberValue(groupKey, item.key, item.default) }]"
                        :placeholder="item.default ? `${$t('settings.default')}: ${item.default}` : ''"
                        style="width: 100%"
                      />
                    </template>

                    <!-- 布尔开关 -->
                    <template v-else-if="item.type === 'boolean'">
                      <a-switch
                        v-decorator="[item.key, { valuePropName: 'checked', initialValue: getBoolValue(groupKey, item.key, item.default) }]"
                      />
                    </template>

                    <!-- 下拉选择 -->
                    <template v-else-if="item.type === 'select'">
                      <a-select
                        v-decorator="[item.key, { initialValue: getFieldValue(groupKey, item.key) || item.default }]"
                        :placeholder="item.default ? `${$t('settings.default')}: ${item.default}` : $t('settings.pleaseSelect')"
                      >
                        <a-select-option
                          v-for="opt in getSelectOptions(item.options)"
                          :key="opt.value"
                          :value="opt.value"
                        >
                          {{ opt.label }}
                        </a-select-option>
                      </a-select>
                    </template>

                    <div class="field-default" v-if="item.default && item.type !== 'boolean' && item.type !== 'password'">
                      {{ $t('settings.default') }}: {{ item.default }}
                    </div>
                  </a-form-item>
                </a-col>
              </a-row>
            </a-form>
          </a-collapse-panel>
        </a-collapse>
      </div>
    </a-spin>

    <div class="settings-footer">
      <a-button @click="handleReset" :disabled="saving">
        <a-icon type="undo" />
        {{ $t('settings.reset') }}
      </a-button>
      <a-button type="primary" @click="handleSave" :loading="saving">
        <a-icon type="save" />
        {{ $t('settings.save') }}
      </a-button>
    </div>

  </div>
</template>

<script>
import { getSettingsSchema, getSettingsValues, saveSettings, getOpenRouterBalance, getAIModels } from '@/api/settings'
import { baseMixin } from '@/store/app-mixin'

export default {
  name: 'Settings',
  mixins: [baseMixin],
  data () {
    return {
      loading: false,
      saving: false,
      schema: {},
      values: {},
      activeKeys: ['server', 'auth', 'ai', 'trading'],
      passwordVisible: {},
      showRestartTip: false,
      // OpenRouter 余额
      balanceLoading: false,
      openrouterBalance: null,

      providerModelSelections: {},
      providerModelsByProvider: {},
      providerLoadingByProvider: {}
    }
  },
  computed: {
    isDarkTheme () {
      return this.navTheme === 'dark' || this.navTheme === 'realdark'
    },
    // 按 order 排序的 schema
    sortedSchema () {
      const entries = Object.entries(this.schema)
      entries.sort((a, b) => {
        const orderA = a[1].order || 999
        const orderB = b[1].order || 999
        return orderA - orderB
      })
      const sorted = {}
      for (const [key, value] of entries) {
        sorted[key] = value
      }
      return sorted
    }
  },
  beforeCreate () {
    this.form = this.$form.createForm(this)
  },
  mounted () {
    this.loadSettings()
  },
  methods: {
    // 兼容后端 schema options 两种格式：
    // - string[]: ['openrouter','openai', ...]
    // - {value,label}[]: [{value:'openrouter',label:'OpenRouter'}, ...]
    getSelectOptions (options) {
      const arr = Array.isArray(options) ? options : []
      return arr.map(opt => {
        if (opt && typeof opt === 'object') {
          return {
            value: opt.value != null ? String(opt.value) : '',
            label: opt.label != null ? String(opt.label) : String(opt.value || '')
          }
        }
        return { value: String(opt), label: String(opt) }
      }).filter(o => o.value !== '')
    },
    async loadSettings () {
      this.loading = true
      try {
        const [schemaRes, valuesRes] = await Promise.all([
          getSettingsSchema(),
          getSettingsValues()
        ])

        if (schemaRes.code === 1) {
          this.schema = schemaRes.data
        }

        if (valuesRes.code === 1) {
          this.values = valuesRes.data
        }

        this.$nextTick(() => {
          this.syncModelSelectionsFromValues()
          this.syncModelsJsonFromSelections()
        })
      } catch (error) {
        this.$message.error(this.$t('settings.loadFailed'))
      } finally {
        this.loading = false
      }
    },

    // 查询 OpenRouter 余额
    async queryOpenRouterBalance () {
      this.balanceLoading = true
      try {
        const res = await getOpenRouterBalance()
        if (res.code === 1 && res.data) {
          this.openrouterBalance = res.data
          this.$message.success(this.tOr('settings.balanceQuerySuccess', '余额查询成功'))
        } else {
          this.$message.error(res.msg || this.tOr('settings.balanceQueryFailed', '余额查询失败'))
        }
      } catch (error) {
        this.$message.error(this.tOr('settings.balanceQueryFailed', '余额查询失败'))
      } finally {
        this.balanceLoading = false
      }
    },

    getGroupIcon (groupKey) {
      const icons = {
        auth: 'lock',
        server: 'cloud-server',
        worker: 'schedule',
        notification: 'notification',
        email: 'mail',
        sms: 'phone',
        strategy: 'fund',
        network: 'global',
        app: 'appstore',
        ai: 'robot',
        trading: 'stock',
        data_source: 'database',
        search: 'search',
        agent: 'experiment'
      }
      return icons[groupKey] || 'setting'
    },

    getGroupTitle (groupKey, defaultTitle) {
      const key = `settings.group.${groupKey}`
      const translated = this.$t(key)
      return translated !== key ? translated : defaultTitle
    },

    getItemLabel (groupKey, item) {
      const key = `settings.field.${item.key}`
      const translated = this.$t(key)
      return translated !== key ? translated : item.label
    },

    getItemDescription (groupKey, item) {
      // 先尝试从多语言获取描述
      const key = `settings.desc.${item.key}`
      const translated = this.$t(key)
      if (translated !== key) {
        return translated
      }
      // 回退到后端返回的描述
      return item.description || ''
    },

    getLinkText (linkText) {
      if (!linkText) return this.$t('settings.getApi')
      // 如果是翻译键（以 settings.link. 开头），则翻译
      if (linkText.startsWith('settings.link.')) {
        const translated = this.$t(linkText)
        return translated !== linkText ? translated : linkText
      }
      return linkText
    },

    getFieldValue (groupKey, key) {
      const groupValues = this.values[groupKey] || {}
      return groupValues[key] || ''
    },

    tOr (key, fallback) {
      const translated = this.$t(key)
      return translated !== key ? translated : fallback
    },

    isAiProviderModelKey (key) {
      return [
        'OPENROUTER_MODEL',
        'OPENAI_MODEL',
        'GOOGLE_MODEL',
        'DEEPSEEK_MODEL',
        'GROK_MODEL'
      ].includes(String(key || ''))
    },

    providerForModelKey (key) {
      const map = {
        OPENROUTER_MODEL: 'openrouter',
        OPENAI_MODEL: 'openai',
        GOOGLE_MODEL: 'google',
        DEEPSEEK_MODEL: 'deepseek',
        GROK_MODEL: 'grok'
      }
      return map[String(key || '')] || ''
    },

    fullIdFromEnvModel (provider, envModel) {
      const v = String(envModel || '').trim()
      if (!v) return ''
      if (provider === 'openrouter') return v
      if (provider === 'grok') return `x-ai/${v}`
      return `${provider}/${v}`
    },

    envModelFromFullId (provider, fullId) {
      const v = String(fullId || '').trim()
      if (!v) return ''
      if (provider === 'openrouter') return v
      const parts = v.split('/')
      return parts.length > 1 ? parts.slice(1).join('/') : v
    },

    getProviderModelsMap (modelKey) {
      const provider = this.providerForModelKey(modelKey)
      return this.providerModelsByProvider[provider] || {}
    },

    isProviderLoading (modelKey) {
      const provider = this.providerForModelKey(modelKey)
      return !!this.providerLoadingByProvider[provider]
    },

    syncModelSelectionsFromValues () {
      const aiVals = this.values.ai || {}
      const keys = ['OPENROUTER_MODEL', 'OPENAI_MODEL', 'GOOGLE_MODEL', 'DEEPSEEK_MODEL', 'GROK_MODEL']
      for (const k of keys) {
        const provider = this.providerForModelKey(k)
        const fullId = this.fullIdFromEnvModel(provider, aiVals[k] || '')
        this.$set(this.providerModelSelections, k, fullId ? [fullId] : [])
      }
    },

    async fetchModelsForKey (modelKey) {
      const provider = this.providerForModelKey(modelKey)
      if (!provider) return
      this.$set(this.providerLoadingByProvider, provider, true)
      try {
        const res = await getAIModels(provider)
        const models = res && res.code === 1 && res.data && res.data.models ? res.data.models : null
        if (!models || typeof models !== 'object') {
          this.$message.error(res?.msg || this.tOr('settings.fetchModelsFailed', '拉取失败'))
          return
        }
        this.$set(this.providerModelsByProvider, provider, models)
      } catch (e) {
        this.$message.error(this.tOr('settings.fetchModelsFailed', '拉取失败'))
      } finally {
        this.$set(this.providerLoadingByProvider, provider, false)
      }
    },

    onProviderModelChange (modelKey, ids) {
      const list = Array.isArray(ids) ? ids : []
      this.$set(this.providerModelSelections, modelKey, list)

      const provider = this.providerForModelKey(modelKey)
      const defaultId = list.length > 0 ? list[0] : ''
      const envModel = defaultId ? this.envModelFromFullId(provider, defaultId) : ''
      this.form.setFieldsValue({ [modelKey]: envModel })

      this.syncModelsJsonFromSelections()
    },

    syncModelsJsonFromSelections () {
      const obj = {}
      const selections = this.providerModelSelections || {}
      for (const modelKey of Object.keys(selections)) {
        const ids = selections[modelKey] || []
        const provider = this.providerForModelKey(modelKey)
        const map = this.providerModelsByProvider[provider] || {}
        for (const id of ids) {
          obj[id] = map[id] || obj[id] || id
        }
      }
      this.form.setFieldsValue({ AI_MODELS_JSON: JSON.stringify(obj, null, 2) })
    },

    togglePasswordVisible (key) {
      this.$set(this.passwordVisible, key, !this.passwordVisible[key])
    },

    getNumberValue (groupKey, key, defaultVal) {
      const val = this.getFieldValue(groupKey, key)
      if (val === '' || val === null || val === undefined) {
        return defaultVal ? parseFloat(defaultVal) : null
      }
      return parseFloat(val)
    },

    getBoolValue (groupKey, key, defaultVal) {
      const val = this.getFieldValue(groupKey, key)
      if (val === '' || val === null || val === undefined) {
        return defaultVal === 'True' || defaultVal === 'true' || defaultVal === true
      }
      return val === 'True' || val === 'true' || val === true
    },

    filterModelOption (input, option) {
      const needle = String(input || '').toLowerCase()
      const value = (option && option.componentOptions && option.componentOptions.propsData && option.componentOptions.propsData.value) || ''
      const labelNode = option && option.componentOptions && option.componentOptions.children && option.componentOptions.children[0]
      const label = (labelNode && labelNode.text) || ''
      return String(value).toLowerCase().includes(needle) || String(label).toLowerCase().includes(needle)
    },

    handleReset () {
      this.form.resetFields()
      this.loadSettings()
    },

    copyRestartCommand () {
      const cmd = 'cd backend_api_python && py run.py'
      navigator.clipboard.writeText(cmd).then(() => {
        this.$message.success(this.$t('settings.copySuccess'))
      }).catch(() => {
        this.$message.error(this.$t('settings.copyFailed'))
      })
    },

    async handleSave () {
      this.form.validateFields(async (err, formValues) => {
        if (err) {
          return
        }

        this.saving = true
        try {
          // 按组整理数据
          const data = {}
          for (const groupKey of Object.keys(this.schema)) {
            data[groupKey] = {}
            const group = this.schema[groupKey]
            for (const item of group.items) {
              if (item.key in formValues) {
                let value = formValues[item.key]
                // 布尔值转字符串
                if (item.type === 'boolean') {
                  value = value ? 'True' : 'False'
                }
                data[groupKey][item.key] = value
              }
            }
          }

          const res = await saveSettings(data)
          if (res.code === 1) {
            this.$message.success(res.msg || this.$t('settings.saveSuccess'))
            // 显示重启提示
            if (res.data && res.data.requires_restart) {
              this.showRestartTip = true
            }
            // 重新加载配置
            this.loadSettings()
          } else {
            this.$message.error(res.msg || this.$t('settings.saveFailed'))
          }
        } catch (error) {
          this.$message.error(this.$t('settings.saveFailed') + ': ' + error.message)
        } finally {
          this.saving = false
        }
      })
    }
  }
}
</script>

<style lang="less" scoped>
@primary-color: #1890ff;
@success-color: #52c41a;
@border-radius: 12px;
@card-shadow: 0 4px 20px rgba(0, 0, 0, 0.08);

.settings-page {
  padding: 24px;
  min-height: calc(100vh - 120px);
  background: linear-gradient(180deg, #f8fafc 0%, #f1f5f9 100%);

  .restart-alert {
    margin-bottom: 16px;
    border-radius: 8px;
  }

  .settings-header {
    margin-bottom: 24px;

    .page-title {
      font-size: 24px;
      font-weight: 700;
      margin: 0 0 8px 0;
      color: #1e3a5f;
      display: flex;
      align-items: center;
      gap: 12px;

      .anticon {
        font-size: 28px;
        color: @primary-color;
      }
    }

    .page-desc {
      color: #64748b;
      font-size: 14px;
      margin: 0;
    }
  }

  .settings-content {
    margin-bottom: 80px;
  }

  // OpenRouter 余额查询卡片
  .openrouter-balance-card {
    margin-bottom: 20px;

    .ant-card {
      background: linear-gradient(135deg, #e6f7ff 0%, #f0f5ff 100%);
      border: 1px solid #91d5ff;
      border-radius: 8px;
    }

    .balance-header {
      display: flex;
      justify-content: space-between;
      align-items: center;
      margin-bottom: 12px;

      .balance-title {
        font-size: 15px;
        font-weight: 600;
        color: #1890ff;
      }
    }

    .balance-info {
      padding: 8px 0;

      /deep/ .ant-statistic-title {
        font-size: 12px;
        color: #666;
      }

      /deep/ .ant-statistic-content {
        font-size: 18px;
      }

      .free-tier-badge {
        margin-top: 12px;
        text-align: right;
      }
    }

    .balance-empty {
      color: #8c8c8c;
      font-size: 13px;
      padding: 8px 0;
    }
  }

  .settings-collapse {
    background: transparent;

    /deep/ .ant-collapse-item {
      margin-bottom: 16px;
      border: none;
      border-radius: @border-radius;
      overflow: hidden;
      background: #fff;
      box-shadow: @card-shadow;

      .ant-collapse-header {
        font-size: 16px;
        font-weight: 600;
        color: #1e3a5f;
        padding: 16px 24px;
        padding-left: 48px;
        background: linear-gradient(135deg, #fff 0%, #f8fafc 100%);
        border-bottom: 1px solid #f0f0f0;
        display: flex;
        align-items: center;

        .ant-collapse-arrow {
          color: @primary-color;
          left: 20px;
        }

        .panel-header {
          display: inline-flex;
          align-items: center;
          gap: 10px;
          flex: 1;

          .panel-icon-left {
            font-size: 18px;
            color: @primary-color;
          }

          .panel-title {
            font-size: 16px;
          }
        }
      }

      .ant-collapse-content {
        border-top: none;

        .ant-collapse-content-box {
          padding: 24px;
        }
      }
    }
  }

  .settings-form {
    /deep/ .ant-form-item-label {
      padding-bottom: 4px;

      label {
        color: #475569;
        font-weight: 500;
      }

      .form-label-with-tooltip {
        display: flex;
        align-items: center;
        gap: 6px;
        flex-wrap: wrap;

        .label-text {
          color: #475569;
          font-weight: 500;
        }

        .help-icon {
          font-size: 14px;
          color: #94a3b8;
          cursor: help;
          transition: color 0.2s;

          &:hover {
            color: @primary-color;
          }
        }

        .api-link {
          font-size: 12px;
          font-weight: 400;
          color: @primary-color;
          text-decoration: none;
          display: inline-flex;
          align-items: center;
          gap: 4px;
          padding: 2px 8px;
          background: rgba(24, 144, 255, 0.08);
          border-radius: 4px;
          transition: all 0.2s;
          margin-left: 4px;

          &:hover {
            background: rgba(24, 144, 255, 0.15);
            color: darken(@primary-color, 10%);
          }

          .anticon {
            font-size: 11px;
          }
        }
      }
    }

    /deep/ .ant-input,
    /deep/ .ant-input-number,
    /deep/ .ant-select-selection {
      border-radius: 8px;
    }

    /deep/ .ant-input-number {
      width: 100%;
    }

    .password-field {
      .field-hint {
        margin-top: 4px;
        font-size: 12px;
        color: @success-color;
        display: flex;
        align-items: center;
        gap: 4px;
      }
    }

    .field-default {
      margin-top: 4px;
      font-size: 12px;
      color: #94a3b8;
    }
  }

  .settings-footer {
    position: fixed;
    bottom: 0;
    left: 208px;
    right: 0;
    padding: 16px 24px;
    background: #fff;
    box-shadow: 0 -4px 20px rgba(0, 0, 0, 0.08);
    display: flex;
    justify-content: flex-end;
    gap: 12px;
    z-index: 100;

    .ant-btn {
      min-width: 100px;
      height: 40px;
      border-radius: 8px;
      font-weight: 500;
    }
  }

  // 暗黑主题
  &.theme-dark {
    background: linear-gradient(180deg, #0d1117 0%, #161b22 100%);

    .restart-alert {
      background: #2d333b;
      border-color: #b08800;
    }

    .settings-header {
      .page-title {
        color: #e0e6ed;
      }

      .page-desc {
        color: #8b949e;
      }
    }

    .settings-collapse {
      /deep/ .ant-collapse-item {
        background: #1e222d;
        box-shadow: 0 4px 24px rgba(0, 0, 0, 0.25);

        .ant-collapse-header {
          background: linear-gradient(135deg, #252a36 0%, #1e222d 100%);
          color: #e0e6ed;
          border-bottom-color: rgba(255, 255, 255, 0.06);

          .panel-header {
            .panel-icon-left {
              color: #58a6ff;
            }
            .panel-title {
              color: #e0e6ed;
            }
          }
        }

        .ant-collapse-content {
          background: #1e222d;

          .ant-collapse-content-box {
            background: #1e222d;
          }
        }
      }
    }

    .settings-form {
      /deep/ .ant-form-item-label {
        label {
          color: #c9d1d9;
        }

        .form-label-with-tooltip {
          .label-text {
            color: #c9d1d9;
          }

          .help-icon {
            color: #6e7681;

            &:hover {
              color: #58a6ff;
            }
          }

          .api-link {
            background: rgba(24, 144, 255, 0.15);
            color: #58a6ff;

            &:hover {
              background: rgba(24, 144, 255, 0.25);
            }
          }
        }
      }

      /deep/ .ant-input,
      /deep/ .ant-input-password,
      /deep/ .ant-input-number,
      /deep/ .ant-select-selection {
        background: #0d1117;
        border-color: #30363d;
        color: #c9d1d9;

        &:hover,
        &:focus {
          border-color: @primary-color;
        }
      }

      /deep/ .ant-input-number-input {
        background: transparent;
        color: #c9d1d9;
      }

      /deep/ .ant-select-arrow {
        color: #8b949e;
      }

      .field-default {
        color: #6e7681;
      }
    }

    .settings-footer {
      background: #1e222d;
      border-top: 1px solid rgba(255, 255, 255, 0.06);
      box-shadow: 0 -4px 24px rgba(0, 0, 0, 0.25);
    }
  }
}

// 响应式适配
@media (max-width: 768px) {
  .settings-page {
    padding: 16px;

    .settings-footer {
      left: 0;
      padding: 12px 16px;
    }
  }
}
</style>
