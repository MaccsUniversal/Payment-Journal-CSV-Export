
pageextension 99011 "Payment Journal MO" extends "Payment Journal"
{
    layout
    {
        // Add changes to page layout here
    }

    actions
    {
        addFirst("Electronic Payments")
        {

            action(ExportPaymentFile)
            {
                Caption = 'Export Payment CSV';
                Promoted = true;
                PromotedCategory = Category4;
                Image = ExportFile;
                ApplicationArea = All;

                trigger OnAction()
                begin
                    Xmlport.Run(99001, false, false);
                end;
            }
        }
    }

    var
        myInt: Integer;
}
xmlport 99001 "Payment Journal Export MOO"
{
    Format = VariableText;
    Direction = Export;
    TextEncoding = UTF8;
    UseRequestPage = false;
    TableSeparator = '<NewLine>';
    FieldSeparator = ',';
    FileName = 'Payment Export File.csv';



    schema
    {
        textelement(Root)
        {
            XmlName = 'Root';

            tableelement(HeaderRow; Integer)
            {
                SourceTableView = sorting(number) where(number = const(1));
                XmlName = 'HeaderRow';

                textelement(Header) { }

                textelement(CurrentDate) { }

                textelement(SequenceNumber) { }

            }
            tableelement(BankCard; "Bank Account")
            {
                SourceTableView = where("No." = filter('LLOYDS BANK'));
                XmlName = 'SenderBankDetails';
                textelement(BankLineLabel)
                {
                    trigger OnBeforePassVariable()
                    begin
                        if BankCard."No." = 'LLOYDS BANK' then
                            BankLineLabel := Format('D');
                    end;
                }

                textelement(ValueDate) { }

                textelement(DebitAccountReference)
                {
                    trigger OnBeforePassVariable()
                    begin
                        DebitAccountReference := Format('Suppliers');
                    end;
                }

                textelement(DebitAccountNumber)
                {

                    trigger OnBeforePassVariable()
                    var
                        AccountNo: Text;
                        SortCode: Text;
                    begin
                        AccountNo := Format(BankCard."Bank Account No.");
                        SortCode := Format(BankCard."Bank Branch No.");
                        DebitAccountNumber := Format(SortCode + '-' + AccountNo);
                    end;
                }

                textelement(BlankField4) { }

            }
            tableelement("GenJournalLine"; "Gen. Journal Line")
            {

                SourceTableView = where("Journal Batch Name" = filter('DEFAULT'), "Account No." = filter(<> ''));
                XmlName = 'Lines';
                textelement(Creditor) { }

                textelement(PaymentAmount)
                {
                    trigger OnBeforePassVariable()
                    begin
                        PaymentAmount := Format(GenJournalLine.Amount, 8, 2);
                        if GenJournalLine.Amount <= 0 then
                            Error('Payment amount must be greater that ''0.00''. General Journal Batch Name=%1, General Journal Line=%2, Account No=%3.', GenJournalLine."Journal Batch Name", GenJournalLine."Line No.", GenJournalLine."Account No.");
                    end;

                }

                textelement(BeneficiaryName)
                {
                    trigger OnBeforePassVariable()
                    begin
                        BeneficiaryName := Format(GenJournalLine.Description, 14)
                    end;
                }

                textelement(BeneficiaryAccountNo)
                {
                    trigger OnBeforePassVariable()
                    begin
                        BeneficiaryAccountNo := GetBankDetails('BeneficiaryAccountNo');
                        if StrLen(BeneficiaryAccountNo) <> 8 then
                            Error('Bank Account No. should be 8 digits long for UK suppliers. General Journal Batch Name=%1, General Journal Line=%2, Account No=%3,', GenJournalLine."Journal Batch Name", GenJournalLine."Line No.", GenJournalLine."Account No.");
                    end;
                }

                textelement(BeneficiarySortCode)
                {
                    trigger OnBeforePassVariable()
                    var
                        VendorBankAcc: Record "Vendor Bank Account";
                    begin
                        BeneficiarySortCode := GetBankDetails('BeneficiarySortCode');
                        if StrLen(BeneficiarySortCode) <> 6 then
                            Error('Bank Sort Code should be 6 digits long for UK suppliers. General Journal Batch Name=%1, General Journal Line=%2, Account No=%3.', GenJournalLine."Journal Batch Name", GenJournalLine."Line No.", GenJournalLine."Account No.");
                    end;
                }

                textelement(CompanyName) { }
            }
            tableelement(Terminate; Integer)
            {
                SourceTableView = sorting(Number) where(Number = Const(1));
                XmlName = 'TerminateLine';

                textelement(TerminateProcess) { }
            }

        }

    }

    trigger OnInitXmlPort()
    var
        DateFormat: Text;
    begin
        IsAccountNoBlank();
        DateFormat := '<Year4><Month,2><Day,2>';
        Header := 'H';
        CurrentDate := Format(Today(), 8, DateFormat);
        ValueDate := Format(GetPostingDate(), 8, DateFormat);
        SequenceNumber := '1';
        Creditor := 'C';
        CompanyName := 'Sovereign Part';
        TerminateProcess := 'T';
    end;

    local procedure GetBankDetails(AccountDetail: Text): Text
    var
        VendorBankAcc: Record "Vendor Bank Account";
    begin
        VendorBankAcc.SetFilter("Vendor No.", GenJournalLine."Account No.");
        VendorBankAcc.SetCurrentKey("Vendor No.");
        if not VendorBankAcc.FindSet() then
            error('Cannot find Vendor Account No for Recipient Bank Account. General Journal Line=%1 General Journal Line Batch Name=%2', GenJournalLine."Line No.", GenJournalLine."Journal Batch Name");
        VendorBankAcc.TestField(Code, GenJournalLine."Account No.");
        case AccountDetail of
            'BeneficiaryAccountNo':
                exit(Format(VendorBankAcc."Bank Account No."));
            'BeneficiarySortCode':
                exit(Format(VendorBankAcc."Bank Branch No."));
        end;
        VendorBankAcc.Reset();
    end;

    local procedure GetPostingDate(): Date
    var
        GenJnlLines: Record "Gen. Journal Line";
    begin
        GenJnlLines.Reset();
        GenJnlLines.SetFilter("Journal Batch Name", 'PAYMENTS');
        GenJnlLines.SetFilter("Journal Batch Name", 'DEFAULT');
        GenJnlLines.FindLast();
        exit(GenJnlLines."Posting Date");
    end;

    local procedure IsAccountNoBlank()
    var
        GenJnlLine: Record "Gen. Journal Line";
        ExportErrorInfo: ErrorInfo;
        Count: Integer;
    begin
        GenJnlLine.Reset();
        GenJnlLine.SetFilter("Journal Template Name", 'PAYMENTS');
        case GenJnlLine.FindSet() of
            true:
                repeat
                    if GenJnlLine."Account No." = '' then begin
                        ExportErrorInfo.Title('Export CSV');
                        ExportErrorInfo.Message('One or more lines do not have an Account No.');
                        Error(ExportErrorInfo);
                    end;
                until GenJnlLine.Next() <= 0;
            false:
                if (GenJnlLine.Count <= 1) and (GenJnlLine."Account No." = '') then begin
                    ExportErrorInfo.Title('Export CSV');
                    ExportErrorInfo.Message('Nothing to export');
                    Error(ExportErrorInfo);
                end;
        end;
    end;

}

