import { createElement } from 'lwc';
import BankAccountCard from 'c/bankAccountCard';
import getLiveBalance from '@salesforce/apex/BankAccountController.getLiveBalance';

jest.mock(
    '@salesforce/apex/BankAccountController.getLiveBalance',
    () => ({ default: jest.fn() }),
    { virtual: true }
);

function flush() {
    // let the async connectedCallback chain + re-render settle
    return new Promise((resolve) => setTimeout(resolve, 0));
}

describe('c-bank-account-card', () => {
    afterEach(() => {
        while (document.body.firstChild) {
            document.body.removeChild(document.body.firstChild);
        }
        jest.clearAllMocks();
    });

    it('renders the formatted balance on success', async () => {
        getLiveBalance.mockResolvedValue({
            accountId: 'a01',
            balanceMinor: 250000,
            currencyCode: 'USD',
            asOf: '2026-06-17T00:00:00Z'
        });

        const el = createElement('c-bank-account-card', { is: BankAccountCard });
        el.recordId = 'a01';
        document.body.appendChild(el);
        await flush();

        expect(getLiveBalance).toHaveBeenCalledWith({ bankAccountId: 'a01' });
        expect(el.shadowRoot.textContent).toContain('2,500'); // 250000 minor → 2,500.00
    });

    it('shows a fail-soft message when the callout fails', async () => {
        getLiveBalance.mockRejectedValue(new Error('core down'));

        const el = createElement('c-bank-account-card', { is: BankAccountCard });
        el.recordId = 'a01';
        document.body.appendChild(el);
        await flush();

        expect(el.shadowRoot.textContent).toContain('temporarily unavailable');
    });
});
