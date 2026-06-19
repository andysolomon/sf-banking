import { LightningElement, api } from 'lwc';
import getLiveBalance from '@salesforce/apex/BankAccountController.getLiveBalance';

export default class BankAccountCard extends LightningElement {
    @api recordId;

    balance;
    asOf;
    error;
    loading = true;

    connectedCallback() {
        this.loadBalance();
    }

    // Imperative (not @wire): a callout must not be cached/replayed by the wire service.
    async loadBalance() {
        this.loading = true;
        this.error = undefined;
        try {
            const v = await getLiveBalance({ bankAccountId: this.recordId });
            const currency = v.currencyCode || 'USD';
            this.balance = (v.balanceMinor / 100).toLocaleString(undefined, {
                style: 'currency',
                currency
            });
            this.asOf = v.asOf;
        } catch (e) {
            // Fail-soft: never show a stack/error page for a transient core-banking issue.
            this.balance = undefined;
            this.error = 'Balance temporarily unavailable';
        } finally {
            this.loading = false;
        }
    }
}
